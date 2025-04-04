#!/bin/bash

REGISTRY_URL="docker-registry"
USERNAME="username"
PASSWORD="password"

DOCKER_HUB="docker.io"

echo "Which?:"
echo "1) Pull and push new image or update specify image:tag"
echo "2) Update all images in your docker registry"
read -p "Enter your choice (1 or 2): " choice

if [[ "$choice" -eq 1 ]]; then
  read -p "Enter the image:tag (default tag is 'latest' if not specified): " user_input

  if [[ -z "$user_input" ]]; then
    echo "No input provided. Exiting..."
    exit 1
  fi

  # Extract repository and tag, default tag is "latest"
  if [[ "$user_input" == *":"* ]]; then
    repo=$(echo "$user_input" | rev | cut -d':' -f2- | rev)
    tag=$(echo "$user_input" | rev | cut -d':' -f1 | rev)
  else
    repo="$user_input"
    tag="latest"
  fi

  image="$REGISTRY_URL/$repo:$tag"
  hub_image="$DOCKER_HUB/$repo:$tag"

  echo "Checking if $image exists in the registry..."
  status=$(curl -s -o /dev/null -w "%{http_code}" -u "$USERNAME:$PASSWORD" "https://$REGISTRY_URL/v2/$repo/manifests/$tag")

  if [[ "$status" -eq 200 ]]; then
    echo "$image exists in the registry. Updating the image..."
    docker pull "$hub_image" || { echo "Failed to pull $hub_image from Docker Hub. Exiting..."; exit 1; }
  else
    echo "$image does not exist in the registry. Pulling from Docker Hub..."
    docker pull "$hub_image" || { echo "Failed to pull $hub_image from Docker Hub. Exiting..."; exit 1; }

    echo "Tagging image as $image..."
    docker tag "$hub_image" "$image"
  fi

  echo "Pushing $image to the private registry..."
  docker push "$image" || { echo "Failed to push $image. Exiting..."; exit 1; }

  echo "Removing local image to free up space..."
  docker rmi "$hub_image" "$image" || { echo "Failed to remove local images."; }

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
      hub_image="$DOCKER_HUB/$repo:$tag"
      echo "Processing image: $image"

      echo "Pulling $hub_image from Docker Hub..."
      docker pull "$hub_image" || { echo "Failed to pull $hub_image from Docker Hub. Skipping..."; continue; }

      echo "Tagging image as $image..."
      docker tag "$hub_image" "$image"

      echo "Pushing $image to the private registry..."
      docker push "$image" || { echo "Failed to push $image. Skipping..."; continue; }

      echo "Removing local image to free up space..."
      docker rmi "$hub_image" "$image" || { echo "Failed to remove local images."; }

      echo "Successfully processed $image."
    done
  done

  echo "All repositories and tags processed."
else
  echo "Invalid choice. Exiting..."
  exit 1
fi
