<?php
/**
 * Plugin Name: Catalog Mode
 * Description: WooCommerce chỉ để giới thiệu sản phẩm: tắt mua hàng, giỏ hàng, thanh toán và tài khoản khách.
 */

if (!defined('ABSPATH')) {
    exit;
}

add_filter('woocommerce_is_purchasable', '__return_false');
add_filter('woocommerce_variation_is_purchasable', '__return_false');
add_filter('woocommerce_loop_add_to_cart_link', '__return_empty_string');
add_filter('woocommerce_widget_cart_is_hidden', '__return_true');
add_filter('woocommerce_enable_order_notes_field', '__return_false');
add_filter('option_woocommerce_enable_myaccount_registration', fn() => 'no');
add_filter('option_woocommerce_enable_checkout_login_reminder', fn() => 'no');

// Giỏ hàng / thanh toán / tài khoản không dùng: đưa về trang Sản phẩm.
add_action('template_redirect', function () {
    if (!function_exists('is_cart')) {
        return;
    }
    if (is_cart() || is_checkout() || is_account_page()) {
        wp_safe_redirect(wc_get_page_permalink('shop'), 302);
        exit;
    }
});

// Ẩn biểu tượng giỏ hàng nếu theme có hiển thị.
add_action('wp_head', function () {
    echo '<style>.ast-site-header-cart,.ast-header-woo-cart,.woocommerce-cart-link,.widget_shopping_cart,.single_add_to_cart_button,.woocommerce-store-notice{display:none!important}</style>';
});
