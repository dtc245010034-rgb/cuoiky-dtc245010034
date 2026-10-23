# Được `source` bởi các init script (đuôi .inc nên entrypoint của image không tự chạy file này).
# Đổi CIDR sang dạng host của MySQL: 10.250.20.0/24 -> 10.250.20.0/255.255.255.0
cidr_to_host_pattern() {
  local ip="${1%/*}" prefix="${1#*/}" mask="" i
  for i in 1 2 3 4; do
    if (( prefix >= 8 )); then mask+="255"; prefix=$(( prefix - 8 ))
    else mask+="$(( 256 - (1 << (8 - prefix)) ))"; prefix=0; fi
    (( i < 4 )) && mask+="."
  done
  printf '%s/%s' "$ip" "$mask"
}
