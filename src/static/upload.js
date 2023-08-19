const upload_button = document.getElementById("upload-button");
const upload_dialog = document.getElementById("upload-dialog");
const upload_form = document.getElementById("upload-form");
const upload_file_path_selector = document.getElementById("upload-file-path-selector");
const upload_file_selector = document.getElementById("upload-file-selector");
const upload_file_selector_label = document.getElementById("upload-file-selector-label");
const upload_error = document.getElementById("upload-error");

upload_button.addEventListener('click', e => {
    e.preventDefault();
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

        fetch("/f/" + upload_file_path_selector.value + "/" + file.name, { method: "POST", body: encoded }).then(async e => {
            if (e.status == 200) {
                location.reload();
            } else {
                upload_error.innerText = "upload failed";
            }
        }).catch(e => {
            alert(e);
        });
    });

    file_reader.readAsBinaryString(file);
});

document.addEventListener('click', e => {
    if(!upload_dialog.open) return;

    const x = e.offsetX;
    const y = e.offsetY;

    if(x < 0 || y < 0 || x > upload_dialog.scrollWidth || y > upload_dialog.scrollHeight) {
        upload_dialog.close();
    }
})

