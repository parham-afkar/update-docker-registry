#!/bin/bash

REGISTRY_URL="docker-registry"
USERNAME="username"
PASSWORD="password"

echo "Which?:"
echo "1) Pull and push new image or update specify image:tag"
echo "2) Update all images in your docker registry"
read -p "Enter your choice (1 or 2): " choice

if [[ "$choice" -eq 1 ]]; then
  read -p "Enter the image:tag: " user_input

  if [[ -z "$user_input" ]]; then
    echo "No input provided. Exiting..."
    exit 1
  fi

  repo=$(echo "$user_input" | cut -d':' -f1)
  tag=$(echo "$user_input" | cut -d':' -f2)

  if [[ -z "$repo" || -z "$tag" ]]; then
    echo "Invalid input. Ensure the format is repository_name:image_tag."
    exit 1
  fi

  image="$REGISTRY_URL/$repo:$tag"

  echo "Checking if $image exists in the registry..."
  status=$(curl -s -o /dev/null -w "%{http_code}" -u "$USERNAME:$PASSWORD" "https://$REGISTRY_URL/v2/$repo/manifests/$tag")

  if [[ "$status" -eq 200 ]]; then
    echo "$image exists in the registry. Updating the image..."
    docker pull "$image" || { echo "Failed to pull $image. Exiting..."; exit 1; }
  else
    echo "$image does not exist in the registry. Pulling from another source..."
    docker pull "$repo:$tag" || { echo "Failed to pull $repo:$tag from the default source. Exiting..."; exit 1; }

    echo "Tagging image as $image..."
    docker tag "$repo:$tag" "$image"
  fi

  echo "Pushing $image to the registry..."
  docker push "$image" || { echo "Failed to push $image. Exiting..."; exit 1; }

  echo "Successfully processed $image."

elif [[ "$choice" -eq 2 ]]; then
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
else
  echo "Invalid choice. Exiting..."
  exit 1
fi
