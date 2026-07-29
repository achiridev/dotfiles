// utils/Time.js

.pragma library

function getCurrentTime(format = "hh:mm:ss") {
    return Qt.formatDateTime(new Date(), format);
}
