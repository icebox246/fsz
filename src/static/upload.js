const upload_button = document.getElementById("upload-button");
const upload_dialog = document.getElementById("upload-dialog");
const upload_form = document.getElementById("upload-form");
const upload_file_path_selector = document.getElementById("upload-file-path-selector");
const upload_file_selector = document.getElementById("upload-file-selector");
const upload_file_selector_label = document.getElementById("upload-file-selector-label");
const upload_error = document.getElementById("upload-error");
const upload_status = document.getElementById("upload-status");

let currently_uploading = false;

function set_upload_status(status, file, extra) {
    if (status == "progress") {
        upload_status.classList.remove("error");
        upload_status.innerText = `uploading: ${file} (${extra})...`
    }
    if (status == "fail") {
        upload_status.classList.add("error");
        upload_status.innerText = `failed to upload: ${file} (${extra}) :(`
    }
    if (status == "finished") {
        upload_status.classList.remove("error");
        upload_status.innerText = `finished uploading: ${file} :)`
    }
}

upload_button.addEventListener('click', e => {
    e.preventDefault();
    if (currently_uploading) return;
    upload_error.innerText = "";
    upload_file_selector_label.innerText = "Select file...";
    upload_file_path_selector.value = location.pathname.substring(2);

    upload_dialog.showModal();
})

upload_file_selector.addEventListener("change", e => {
    e.preventDefault();

    if (upload_file_selector.files.length < 1) return;

    const file = upload_file_selector.files[0];

    upload_file_selector_label.innerText = `Selected: '${file.name}'`;

    const file_reader = new FileReader();

    file_reader.addEventListener("load", () => {
        const data = file_reader.result;

        const encoded = btoa(data) + "\0";

        const xhr = new XMLHttpRequest();

        xhr.upload.addEventListener("progress", e => {
            const progress = e.loaded / e.total;
            const percent = ~~(100 * progress) + "%"
            set_upload_status("progress", file.name, percent);
        })

        xhr.addEventListener("loadend", () => {
            if (xhr.status == 200) {
                set_upload_status("finished", file.name);
                location.reload();
            } else {
                set_upload_status("fail", file.name, xhr.status);
                upload_error.innerText = "upload failed";
            }
            currently_uploading = false;
        })

        xhr.open("POST", "/f/" + upload_file_path_selector.value + "/" + file.name);

        xhr.send(encoded);

        currently_uploading = true;
    });

    file_reader.readAsBinaryString(file);
});

document.addEventListener('click', e => {
    if (!upload_dialog.open) return;

    const x = e.offsetX;
    const y = e.offsetY;

    if (x < 0 || y < 0 || x > upload_dialog.scrollWidth || y > upload_dialog.scrollHeight) {
        upload_dialog.close();
    }
})

