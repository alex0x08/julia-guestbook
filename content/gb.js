/**
 * Javascript класс для "Упоротой гостевой"
 * @author Alex Chernyshev <mailto:alex3.145@gmail.com>
 */
class GuestBook {
    /**
     * Добавляет новый DOM-элемент на страницу с данными поста из JSON.
     * @param {*} messagesEl 
     * @param {*} record 
     * @param {*} prepend 
     */
    addRecordFromTemplate(messagesEl, record, prepend) {
        let cloneEl = document.querySelector('#message-template').cloneNode(true);
        cloneEl.setAttribute('id', 'id_' + record.id);
        cloneEl.querySelector('#message-title').innerHTML = record.title;
        cloneEl.querySelector('#message-text').innerHTML = record.message;
        cloneEl.querySelector('#message-author').innerHTML = record.author;
        cloneEl.querySelector('#message-date').innerText = record.createdDt;
        const deleteBtn = cloneEl.querySelector('#deleteBtn');
        if (deleteBtn) { deleteBtn.addEventListener('click', (e) => { e.preventDefault();
                if (window.confirm(deleteBtn.getAttribute('confirm'))) { gb.deleteRecord(record.id); }
            });
        }
        if (prepend) { messagesEl.insertBefore(cloneEl, messagesEl.firstChild); } else { messagesEl.appendChild(cloneEl); }
        cloneEl.style.display = '';
    }
    /**
     * Отправляет новую запись на сервер
     */
    addRecord() {
        const self = this;
        let author = self.escapeHTML(document.querySelector('#authorInput').value);
        let title = self.escapeHTML(document.querySelector('#titleInput').value);
        let message = self.escapeHTML(document.querySelector('#messageInput').value);
        fetch('/api/add', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ title: title, author: author, message: message })
        }).then(response => {
            if (!response.ok) {
                document.querySelector('#errorAlert').style.display = '';
                throw new Error(response.statusText);
            } else { document.querySelector('#errorAlert').style.display = 'none'; }
            return response.json()
        }).then(record => {
            console.log('новая запись:', record);
            document.querySelector('#newRecordForm').reset();
            self.addRecordFromTemplate(document.querySelector('#messages'), record, true);
        }).catch(error => { console.log("ошибка при добавлении записи: ", error); });
    }
    /**
     * Загружает посты гостевой
     */
    loadRecords() {
        const self = this;
        fetch('/api/records', { method: 'GET', headers: {} }).then(response => response.json()).then(records => {
            console.log('загруженные записи:', records);
            let messagesEl = document.querySelector('#messages'); messagesEl.innerHTML = "";
            records.forEach(record => { self.addRecordFromTemplate(messagesEl, record, false); });
        }).catch(error => { console.log("не могу добавить: ", error); });
    }
    /**
    * Удаляет запись из гостевой
    *
    * @param recordId
                id записи
    */
    deleteRecord(recordId) {
        console.log("удаление записи: ", recordId);
        fetch('/api/delete?' + new URLSearchParams({ id: recordId }), { method: 'POST', headers: {} }).then((response) => {
            if (response.ok) { gb.loadRecords(); }
        }).catch(error => { console.log("ошибка при удалении записи: ", error); });
    }
    /**
      Очень простой вариант HTML escape, только для тестов
    */
    escapeHTML(unsafe) { return unsafe.replace(/[\u0000-\u002F\u003A-\u0040\u005B-\u0060\u007B-\u00FF]/g,
        c => '&#' + ('000' + c.charCodeAt(0)).slice(-4) + ';');
    }
}
// статичный инстанс
const gb = new GuestBook();
// добавление обработчиков событий при загрузке страницы
window.onload = () => {
    document.querySelector('#submitBtn').addEventListener('click', (e) => { e.preventDefault(); gb.addRecord(); });
    document.querySelector('#newRecordForm').addEventListener('submit', (e) => { e.preventDefault(); gb.addRecord(); });
    gb.loadRecords();
};