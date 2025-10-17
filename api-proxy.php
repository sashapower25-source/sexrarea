<?php
/**
 * API Proxy для проксирования запросов к backend API
 * Обрабатывает CORS, логирование и перенаправление запросов
 */

// Настройки
$BACKEND_URL = 'http://localhost:3000'; // URL вашего Node.js backend
$ALLOWED_ORIGINS = ['*']; // Разрешенные домены для CORS
$LOG_FILE = '/var/log/nginx/api-proxy.log';

// Функция для логирования
function logRequest($message) {
    global $LOG_FILE;
    $timestamp = date('Y-m-d H:i:s');
    $logEntry = "[$timestamp] $message" . PHP_EOL;
    file_put_contents($LOG_FILE, $logEntry, FILE_APPEND | LOCK_EX);
}

// Функция для отправки CORS заголовков
function sendCorsHeaders() {
    global $ALLOWED_ORIGINS;
    
    $origin = $_SERVER['HTTP_ORIGIN'] ?? '';
    
    if (in_array('*', $ALLOWED_ORIGINS) || in_array($origin, $ALLOWED_ORIGINS)) {
        header("Access-Control-Allow-Origin: " . ($origin ?: '*'));
    }
    
    header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
    header('Access-Control-Allow-Credentials: true');
    header('Access-Control-Max-Age: 86400');
}

// Обработка preflight OPTIONS запросов
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    sendCorsHeaders();
    http_response_code(200);
    exit;
}

// Логирование входящего запроса
$requestMethod = $_SERVER['REQUEST_METHOD'];
$requestUri = $_SERVER['REQUEST_URI'];
$userAgent = $_SERVER['HTTP_USER_AGENT'] ?? 'Unknown';
$clientIp = $_SERVER['REMOTE_ADDR'] ?? 'Unknown';

logRequest("Incoming request: $requestMethod $requestUri from $clientIp (User-Agent: $userAgent)");

// Получение данных запроса
$requestData = null;
if (in_array($requestMethod, ['POST', 'PUT', 'PATCH'])) {
    $requestData = file_get_contents('php://input');
}

// Подготовка заголовков для backend
$headers = [];
foreach (getallheaders() as $name => $value) {
    // Исключаем некоторые заголовки
    if (!in_array(strtolower($name), ['host', 'content-length', 'connection'])) {
        $headers[] = "$name: $value";
    }
}

// Добавляем заголовок с IP клиента
$headers[] = "X-Forwarded-For: $clientIp";
$headers[] = "X-Real-IP: $clientIp";

// Формирование URL для backend
$backendUrl = $BACKEND_URL . $requestUri;

// Инициализация cURL
$ch = curl_init();
curl_setopt_array($ch, [
    CURLOPT_URL => $backendUrl,
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_FOLLOWLOCATION => true,
    CURLOPT_TIMEOUT => 60,
    CURLOPT_CONNECTTIMEOUT => 10,
    CURLOPT_CUSTOMREQUEST => $requestMethod,
    CURLOPT_HTTPHEADER => $headers,
    CURLOPT_HEADER => true,
    CURLOPT_SSL_VERIFYPEER => false,
    CURLOPT_SSL_VERIFYHOST => false,
]);

// Добавление данных тела запроса
if ($requestData) {
    curl_setopt($ch, CURLOPT_POSTFIELDS, $requestData);
}

// Выполнение запроса
$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$error = curl_error($ch);
curl_close($ch);

// Обработка ошибок cURL
if ($error) {
    logRequest("cURL Error: $error");
    sendCorsHeaders();
    http_response_code(502);
    echo json_encode(['error' => 'Backend connection failed', 'details' => $error]);
    exit;
}

// Разделение заголовков и тела ответа
$headerSize = curl_getinfo($ch, CURLINFO_HEADER_SIZE);
$responseHeaders = substr($response, 0, $headerSize);
$responseBody = substr($response, $headerSize);

// Отправка CORS заголовков
sendCorsHeaders();

// Отправка HTTP кода ответа
http_response_code($httpCode);

// Парсинг и отправка заголовков ответа от backend
$headerLines = explode("\r\n", $responseHeaders);
foreach ($headerLines as $headerLine) {
    if (strpos($headerLine, ':') !== false) {
        list($headerName, $headerValue) = explode(':', $headerLine, 2);
        $headerName = trim($headerName);
        $headerValue = trim($headerValue);
        
        // Исключаем некоторые заголовки
        if (!in_array(strtolower($headerName), ['content-encoding', 'transfer-encoding', 'connection'])) {
            header("$headerName: $headerValue");
        }
    }
}

// Логирование ответа
logRequest("Response: HTTP $httpCode, Body length: " . strlen($responseBody));

// Отправка тела ответа
echo $responseBody;
?>

