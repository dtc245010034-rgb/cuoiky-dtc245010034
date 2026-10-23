#!/bin/sh
# Chạy trong container wpcli (profile "setup"): cài WordPress và nạp nội dung mẫu.
# Idempotent: chạy lại không tạo trùng.
set -eu

WP="wp --path=/var/www/html"
step() { printf '\n==> %s\n' "$1"; }

# --- 1. Cài WordPress ---
step "Cài đặt WordPress"
if $WP core is-installed 2>/dev/null; then
  echo "Đã cài, bỏ qua."
else
  $WP core install \
    --url="$WP_SITE_URL" --title="$WP_SITE_TITLE" \
    --admin_user="$WP_ADMIN_USER" --admin_password="$WP_ADMIN_PASSWORD" \
    --admin_email="$WP_ADMIN_EMAIL" --skip-email
fi

$WP option update blogdescription "Thiết bị nhà thông minh: âm thanh, chiếu sáng, phụ kiện"
$WP option update timezone_string "Asia/Ho_Chi_Minh"
$WP option update default_comment_status closed
$WP option update default_ping_status closed
$WP option update blog_public 1
$WP rewrite structure '/%postname%/'

# Ngôn ngữ tiếng Việt (tải bản dịch cần Internet; lỗi thì giữ tiếng Anh)
$WP language core install vi --activate 2>/dev/null || echo "Không tải được ngôn ngữ vi, giữ mặc định."

# --- 2. Theme ---
step "Theme (Astra, dự phòng Twenty Twenty-Five)"
if $WP theme is-installed astra 2>/dev/null || $WP theme install astra 2>&1; then
  $WP theme activate astra
else
  echo "Không tải được Astra, dùng theme có sẵn."
  $WP theme activate twentytwentyfive
fi

# --- 3. WooCommerce (chế độ catalog) ---
step "WooCommerce"
WC=0
if $WP plugin is-installed woocommerce 2>/dev/null || $WP plugin install woocommerce 2>&1; then
  $WP plugin activate woocommerce && WC=1
fi

mkdir -p /var/www/html/wp-content/mu-plugins

# --- 4. Ảnh ---
step "Nạp ảnh vào thư viện media"
import_image() { # $1 = slug ảnh, $2 = tiêu đề; in ra ID attachment (tra theo meta _seed_slug)
  existing=$($WP post list --post_type=attachment --meta_key=_seed_slug --meta_value="$1" --field=ID --posts_per_page=1)
  if [ -n "$existing" ]; then echo "$existing"; return; fi
  new=$($WP media import "/seed/images/$1.png" --title="$2" --porcelain)
  $WP post meta add "$new" _seed_slug "$1" >/dev/null
  echo "$new"
}
BANNER_ID=$(import_image banner "PhucTech Smart Home")
BANNER_URL=$($WP eval "echo wp_get_attachment_url($BANNER_ID);")

# --- 5. Trang ---
step "Trang nội dung"
make_page() { # $1 = slug, $2 = tiêu đề, $3 = file nội dung; in ra ID
  id=$($WP post list --post_type=page --name="$1" --field=ID --posts_per_page=1 || true)
  content=$(sed "s#__BANNER_URL__#$BANNER_URL#g" "$3")
  if [ -z "$id" ]; then
    id=$($WP post create --post_type=page --post_status=publish --post_title="$2" --post_name="$1" --post_content="$content" --porcelain)
  else
    $WP post update "$id" --post_title="$2" --post_content="$content" >/dev/null
  fi
  echo "$id"
}
HOME_ID=$(make_page trang-chu "Trang chủ" /seed/content/home.html)
CONTACT_ID=$(make_page lien-he "Liên hệ" /seed/content/contact.html)

# Xoá nội dung mẫu mặc định
for sample in "post hello-world" "page sample-page"; do
  set -- $sample
  sid=$($WP post list --post_type="$1" --name="$2" --field=ID)
  [ -z "$sid" ] || $WP post delete "$sid" --force
done
COMMENTS=$($WP comment list --format=ids)
[ -z "$COMMENTS" ] || $WP comment delete $COMMENTS --force

if [ "$WC" = 1 ]; then
  step "Cấu hình WooCommerce"
  cp /seed/mu-plugins/catalog-mode.php /var/www/html/wp-content/mu-plugins/catalog-mode.php
  $WP option update woocommerce_currency VND
  $WP option update woocommerce_price_num_decimals 0
  $WP option update woocommerce_currency_pos right_space
  $WP option update woocommerce_price_thousand_sep .
  $WP option update woocommerce_price_decimal_sep ,
  $WP option update woocommerce_default_country VN
  $WP option update woocommerce_calc_taxes no
  $WP option update woocommerce_enable_reviews no
  $WP option update woocommerce_manage_stock no
  # Tắt "Coming soon" mặc định của WooCommerce để khách xem được sản phẩm
  $WP option update woocommerce_coming_soon no
  $WP option update woocommerce_store_pages_only no
  $WP eval 'WC_Install::create_pages();'
  SHOP_ID=$($WP option get woocommerce_shop_page_id)
  $WP post update "$SHOP_ID" --post_title="Sản phẩm" --post_name="san-pham" >/dev/null

  step "Danh mục sản phẩm"
  while IFS='|' read -r slug name desc; do
    [ -n "$slug" ] || continue
    if ! $WP term get product_cat "$slug" --by=slug --field=term_id >/dev/null 2>&1; then
      $WP term create product_cat "$name" --slug="$slug" --description="$desc" --porcelain >/dev/null
    fi
    echo "  $name"
  done < /seed/content/categories.tsv

  step "Sản phẩm"
  while IFS='|' read -r slug name cat price short long; do
    [ -n "$slug" ] || continue
    if [ -n "$($WP post list --post_type=product --name="$slug" --field=ID --post_status=any)" ]; then
      echo "  (đã có) $name"; continue
    fi
    cat_id=$($WP term get product_cat "$cat" --by=slug --field=term_id)
    img_id=$(import_image "$slug" "$name")
    $WP wc product create --user="$WP_ADMIN_USER" --name="$name" --slug="$slug" --type=simple \
      --status=publish --regular_price="$price" --short_description="$short" --description="$long" \
      --categories="[{\"id\":$cat_id}]" --images="[{\"id\":$img_id}]" --porcelain >/dev/null
    echo "  + $name ($price)"
  done < /seed/content/products.tsv
else
  # Dự phòng: không có WooCommerce thì tạo trang giới thiệu sản phẩm thường.
  step "Dự phòng (không WooCommerce): trang Sản phẩm thường"
  make_page san-pham "Sản phẩm" /seed/content/products-fallback.html >/dev/null
fi

# --- 6. Menu & trang chủ ---
step "Menu và trang chủ"
$WP option update show_on_front page
$WP option update page_on_front "$HOME_ID"
$WP option update page_for_posts 0

MENU="Menu chính"
add_item() { # $1 = tiêu đề, $2 = ID trang
  $WP menu item list "$MENU" --format=csv --fields=title | tr -d '"' | grep -qx "$1" || \
    $WP menu item add-post "$MENU" "$2" --title="$1" >/dev/null
}
$WP term list nav_menu --field=name | grep -qx "$MENU" || $WP menu create "$MENU" >/dev/null
SHOP_PAGE=$($WP post list --post_type=page --name=san-pham --field=ID)
add_item "Trang chủ" "$HOME_ID"
add_item "Sản phẩm" "$SHOP_PAGE"
add_item "Liên hệ" "$CONTACT_ID"
# Gán menu cho cả menu desktop và menu di động (tránh theme tự liệt kê mọi trang như Cart/Checkout)
for loc in primary mobile_menu; do
  $WP menu location assign "$MENU" "$loc" 2>/dev/null || echo "Không gán được vị trí '$loc' (theme khác?)"
done

$WP rewrite flush
$WP cache flush >/dev/null 2>&1 || true
step "Hoàn tất. Truy cập: $WP_SITE_URL"
