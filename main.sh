#!/bin/bash

REGISTRY_URL="docker-registry"
USERNAME="username"
PASSWORD="password"

echo "Fetching repository list from $REGISTRY_URL..."
repositories=$(curl -s -u "$USERNAME:$PASSWORD" "https://$REGISTRY_URL/v2/_catalog" | jq -r '.repositories[]')

if [[ -z "$repositories" ]]; then
  echo "No repositories found in the registry."
  exit 0
fi

for repo in $repositories; do
  echo "Processing repository: $repo"

  echo "Fetching tags for $repo..."
  tags=$(curl -s -u "$USERNAME:$PASSWORD" "https://$REGISTRY_URL/v2/$repo/tags/list" | jq -r '.tags[]')

  if [[ -z "$tags" ]]; then
    echo "No tags found for $repo. Skipping..."
    continue
  fi

  for tag in $tags; do
    image="$REGISTRY_URL/$repo:$tag"
    echo "Processing image: $image"

    echo "Pulling $image..."
    docker pull "$image" || { echo "Failed to pull $image. Skipping..."; continue; }

    new_image="$REGISTRY_URL/$repo:$tag"
    echo "Tagging image as $new_image..."
    docker tag "$image" "$new_image"

    echo "Pushing $new_image back to the registry..."
    docker push "$new_image" || { echo "Failed to push $new_image. Skipping..."; continue; }

    echo "Successfully processed $image."
  done
done

echo "All repositories and tags processed."
