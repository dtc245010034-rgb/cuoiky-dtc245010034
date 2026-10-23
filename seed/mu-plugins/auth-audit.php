<?php
/**
 * Plugin Name: Auth Audit
 * Description: Ghi một dòng JSON ra error_log (stderr của php-fpm) mỗi lần đăng nhập thành công/thất bại, để Promtail/Loki thu thập.
 */

if (!defined('ABSPATH')) {
    exit;
}

/**
 * Ghi một sự kiện đăng nhập. Chỉ ghi tên đăng nhập, IP và thời gian — không bao giờ đọc hay ghi mật khẩu.
 * IP lấy từ REMOTE_ADDR: Nginx đặt giá trị này qua fastcgi_params từ $remote_addr nên client không giả mạo được.
 */
function dtc_auth_audit_log(string $event, string $user): void
{
    $ip = $_SERVER['REMOTE_ADDR'] ?? '';
    if (!filter_var($ip, FILTER_VALIDATE_IP)) {
        $ip = 'unknown';
    }

    error_log(wp_json_encode([
        'event' => $event,
        'user'  => mb_substr($user, 0, 60),
        'ip'    => $ip,
        'ts'    => gmdate('c'),
    ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));
}

add_action('wp_login', function ($user_login) {
    dtc_auth_audit_log('LOGIN_OK', (string) $user_login);
}, 10, 1);

add_action('wp_login_failed', function ($username) {
    dtc_auth_audit_log('LOGIN_FAIL', (string) $username);
}, 10, 1);
