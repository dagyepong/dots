#!/bin/bash

# Get the current workspace ID
current_workspace=$(niri msg workspaces | grep \* | awk '{print $2}')

no_empty_workspace=$(niri msg windows | grep Workspace | awk '{print $3}')

# Define the total number of workspaces
total_workspaces=10

# Initialize the target workspace ID
target_workspace=$current_workspace

# Traverse rightward to find a non-empty workspace
for (( i=1; i<=$total_workspaces; i++ )); do
    # Calculate the next workspace ID
    next_workspace=$((($current_workspace + $i - 1) %$total_workspaces + 1))
    
    # Check if the next workspace has a window
    if echo $no_empty_workspace | grep  $next_workspace; then
        target_workspace=$next_workspace
        break
    fi
done

# Switch to the found target workspace
if [ "$target_workspace" != "$current_workspace" ]; then
    niri msg action focus-workspace $target_workspace
    echo $target_workspace
fi
