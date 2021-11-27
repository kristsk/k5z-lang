// Copyright (c) 2021 Krists Krigers <krists dot krigers at gmail dot com>. All rights reserved.
// SPDX-License-Identifier: MIT

function findElement(selector) {

    let element = document.querySelector(selector);

    if (!element) {

        throw new Error('Could not find element for selector "' + selector + '".');
    }

    return element;
}

function updateMuffinContent(container_selector, html) {

    let container_element = findElement(container_selector);

    container_element.html(html.trim());
}

function updateMuffinFrameAttributes(frame_selector, attributesToSet, attributesToRemove = []) {

    let frame_element = findElement(frame_selector);

    Object.getOwnPropertyNames(attributesToSet).forEach((name) => {

        frame_element.setAttribute(name, attributesToSet[name]);
    });

    attributesToRemove.forEach((name) => {

        frame_element.removeAttribute(name);
    });
}

function appendMuffin(anchor_selector, html) {

    let template_element = document.createElement('template');
    template_element.innerHTML = html.trim();
    let muffin_element = template_element.content.firstChild;

    let anchor_element = findElement(anchor_selector);

    anchor_element.parentNode.insertBefore(muffin_element, anchor_element);
}

function removeMuffin(frame_selector) {

    let frame_element = findElement(frame_selector);

    frame_element.parent.removeChild(frame_element);
}
