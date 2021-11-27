// Copyright (c) 2021 Krists Krigers <krists dot krigers at gmail dot com>. All rights reserved.
// SPDX-License-Identifier: MIT

jQuery(function () {

    jQuery('body')
        .on('click', 'button[data-muffin-action-button]', function () {

            if ('incremental' in jQuery(this).data()) {

                let request = jQuery
                    .ajax(jQuery(this).data('url'), {headers: {'Accept': ['application/json+k5z-incremental']}})
                    .done(function (data) {

                        if (request.getResponseHeader('Content-Type').indexOf('text/html') === 0) {

                            jQuery('body').html(jQuery(data));
                        } else {

                            processIncrementalResponse(data);
                        }
                    });
            } else {

                document.location = $(this).data('url');
            }
        })
        .on('click', 'button[data-muffin-form-button]', function () {

            let form = document.getElementById($(this).data('form-id'));

            if ('incremental' in jQuery(this).data()) {

                let form_data = jQuery(form).serializeArray();

                let request = jQuery
                    .ajax({
                            url: jQuery(this).data('url'),
                            headers: {'Accept': ['application/json+k5z-incremental']},
                            method: 'POST',
                            data: form_data
                        }
                    )
                    .done(function (data) {

                        if (request.getResponseHeader('Content-Type').indexOf('text/html') === 0) {

                            jQuery('body').html(jQuery(data));
                        } else {

                            processIncrementalResponse(data);
                        }
                    });
            } else {

                form.action = jQuery(this).data('url');
                form.submit();
            }
        })
        .on('submit', 'form.muffin-form', function () {

            this.action = jQuery(this).find('button.submit').data('url');
        })
        .on('reset', 'form.muffin-form', function () {


            console.log(jQuery(this).find('button.reset').data('url'));

            this.action = jQuery(this).find('button.reset').data('url');
        });

    function getElement(selector) {

        let element = document.querySelector(selector);

        if (!element) {

            throw new Error('Could not find element for selector "' + selector + '".');
        }

        return element;
    }

    function processIncrementalResponse(response) {

        console.log({response: response});

        let map = {
            update_container: updateContainer,
            insert_container: insertContainer,
            remove_container: removeContainer,
            set_css: setCss
        };

        response.forEach(function (operation) {

            if (map[operation.operation_type]) {
                map[operation.operation_type](operation);
            }
        });
    }

    function getMuffinContainerSelector(container_name) {

        return '[data-container-name="' + container_name + '"]';
    }

    function updateContainer(operation) {

        let container_name = operation.container_name;
        let html = operation.content;

        let container_element = getElement(getMuffinContainerSelector(container_name));

        let template_element = document.createElement('template');
        template_element.innerHTML = html.trim();

        template_element.content.firstChild.replaceWith(...template_element.content.firstChild.childNodes);

        container_element.innerHTML = '';
        container_element.appendChild(template_element.content);
    }

    function insertContainer(operation) {

        let selector = operation.selector;
        let html = operation.content;

        let template_element = document.createElement('template');
        template_element.innerHTML = html.trim();
        let muffin_element = template_element.content.firstChild;

        let anchor_element = getElement(selector);

        if (selector === "body") {
            anchor_element.insertBefore(muffin_element, anchor_element.firstChild);
        } else {
            anchor_element.insertBefore(muffin_element, null);
        }
    }

    function removeContainer(operation) {

        let container_name = operation.container_name;

        let container_element = getElement(getMuffinContainerSelector(container_name));

        container_element.parentNode.removeChild(container_element);
    }

    function setCss(operation) {

        let html = operation.content;

        let template_element = document.createElement('template');
        template_element.innerHTML = html.trim();
        let style_element = template_element.content.firstChild;

        let head_element = document.getElementsByTagName('head')[0];
        head_element.appendChild(style_element);
    }
});