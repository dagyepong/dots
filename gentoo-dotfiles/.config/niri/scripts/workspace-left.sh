#!/bin/bash

# Get the current workspace ID
current_workspace=$(niri msg workspaces | grep \* | awk '{print$2}')

no_empty_workspace=$(niri msg windows | grep Workspace | awk '{print$3}')

# Define the total number of workspaces
total_workspaces=10

# Initialize the target workspace ID
target_workspace=$current_workspace

# Traverse leftwards to find a non-empty workspace
for (( i=1; i<=$total_workspaces; i++ )); do
    # Calculate the previous workspace ID
    prev_workspace=$((($current_workspace - $i +$total_workspaces) % $total_workspaces))
    if [ $prev_workspace -eq 0 ]; then
        prev_workspace=$total_workspaces
    fi
    
    # Check if there is a window in the previous workspace
    if echo $no_empty_workspace | grep -w $prev_workspace; then
        target_workspace=$prev_workspace
        break
    fi
done

# Switch to the found target workspace
if [ "$target_workspace" != "$current_workspace" ]; then
    niri msg action focus-workspace $target_workspace
    echo "Switched to workspace: $target_workspace"
fi
