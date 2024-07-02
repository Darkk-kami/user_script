#!/bin/bash

if [ $EUID -ne 0 ]; then
  if [ "$(id -u)" -ne 0 ]; then
    echo "You need root or sudo to run this command"
    exit 1
  fi
fi

if [ -z "$1" ]; then
  echo "$0 Please provide an input file to read from"
  exit 1
fi

input_file="$1"
log_file="/var/log/user_mgt.log"
password_file="/var/secure/user_passwords.csv"

mkdir -p "$(dirname "$log_file")"
touch "$log_file"

mkdir -p "$(dirname "$password_file")"
touch "$password_file"

chmod 600 "$password_file"

generate_password(){
  < /dev/urandom tr -dc A-Za-z0-9 | head -c12
}

while IFS=';' read -r username groups; do
 
  username=$(echo "$username" | xargs)
  groups=$(echo "$groups" | xargs)

  echo "Creating user: $username with groups: $groups ......."
  sleep 4

  if id "$username" &>/dev/null; then
    echo "User $username already exists" | tee -a "$log_file"
    continue
  fi

  if ! getent group "$username" > /dev/null; then
    groupadd "$username"
    if [ $? -ne 0 ]; then
      echo "Failed to create primary group for user $username" | tee -a "$log_file"
      continue
    fi
  fi

  useradd -m -g "$username" "$username"
  if [ $? -ne 0 ]; then
    echo "Failed to create user $username" | tee -a "$log_file"
    continue
  fi

  IFS=',' read -ra group_array <<< "$groups"
  for group in "${group_array[@]}"; do
    group=$(echo "$group" | xargs)
    if ! getent group "$group" > /dev/null; then
      groupadd "$group"
      echo "Group $group created" | tee -a "$log_file"
    fi
    usermod -aG "$group" "$username"
  done

  password=$(generate_password)
  if [ -z "$password" ]; then
    echo "Failed to generate password for $username" | tee -a "$log_file"
    continue
  fi
  echo "$username:$password" | chpasswd

  echo "User $username created with groups $groups" | tee -a "$log_file"
  echo "$username,$password" >> "$password_file"
done < "$input_file"

echo "User creation process completed" | tee -a "$log_file"
