async function requestDelete(filename) {
    const res = await fetch(location.pathname + filename, { method: "DELETE" })

    if (res.status == 200) {
        location.reload();
    } else if (res.status == 403) {
        alert("Could not delete chosen file");
    } else if(res.status == 404) {
        alert("Could not find requested file");
    }
}
