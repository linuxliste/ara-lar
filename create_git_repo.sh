#!/bin/bash

# Kullanım kontrolü
if [[ $# -ne 3 ]]; then
  echo "Kullanım: $0 <PRIVATE_TOKEN> <NAMESPACE_PATH> <REPO_NAME>"
  echo "Örnek : $0 glpat-abc123 do374v2.2 test-repo"
  exit 1
fi

# Argümanlar
TOKEN="$1"
NAMESPACE_PATH="$2"
REPO_NAME="$3"

# GitLab URL (gerekiyorsa düzenle)
GITLAB_URL="https://git.local.lab"


# Grup ID'sini al
GROUP_INFO=$(curl --silent --header "PRIVATE-TOKEN: $TOKEN" \
  "$GITLAB_URL/api/v4/groups?per_page=100")

GROUP_ID=$(echo "$GROUP_INFO" | jq -r '.[] | select(.path=="'"$NAMESPACE_PATH"'") | .id')


# Repo varsa, çık
EXISTING_REPO=$(curl --silent --header "PRIVATE-TOKEN: $TOKEN" \
    "$GITLAB_URL/api/v4/projects?search=$REPO_NAME" | \
    jq -r '.[] | select(.namespace.id == '"$GROUP_ID"') | .name')

if [[ "$EXISTING_REPO" == "$REPO_NAME" ]]; then
  echo "ℹ️  Repo '$REPO_NAME' zaten grup içinde mevcut. Oluşturulmadı."
  exit 0
fi



if [[ -z "$GROUP_ID" ]]; then
  echo "❌ Hata: Grup '$NAMESPACE_PATH' bulunamadı."
  exit 2
fi

echo "✅ Grup '$NAMESPACE_PATH' bulundu (ID: $GROUP_ID). Yeni repo '$REPO_NAME' oluşturuluyor..."

# Repo oluştur
CREATE_RESPONSE=$(curl --silent --write-out "%{http_code}" --output /tmp/create_gitlab_repo_response.json \
  --request POST "$GITLAB_URL/api/v4/projects" \
  --header "PRIVATE-TOKEN: $TOKEN" \
  --form "name=$REPO_NAME" \
  --form "namespace_id=$GROUP_ID")

if [[ "$CREATE_RESPONSE" == "201" ]]; then
  echo "✅ Repo başarıyla oluşturuldu:"
  jq '.ssh_url_to_repo, .http_url_to_repo' < /tmp/create_gitlab_repo_response.json
else
  echo "❌ Repo oluşturulamadı. HTTP kodu: $CREATE_RESPONSE"
  jq < /tmp/create_gitlab_repo_response.json
fi

