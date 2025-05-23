#!/bin/bash
#
# This scripts fetches tasks since last internal release using git log.
#
# Note: this script is intended to be run in CI environment and should not
# be run locally as part of the release process.
#

set -e -o pipefail

asana_api_url="https://app.asana.com/api/1.0"

find_task_urls_in_git_log() {
	local last_release_tag="$1"

	git fetch -q --tags

	# 1. Fetch all commit messages since the last release tag
	# 2. Extract Asana task URLs from the commit messages
	#    (Use -A 1 to handle cases where URL is on the next line after "Task/Issue URL:")
	# 3. Filter only lines containing Asana URLs
	# 4. Remove duplicates
	git log "${last_release_tag}"..HEAD -- ./ ../SharedPackages/BrowserServicesKit/ \
		| grep -A 1 'Task.*URL' \
		| sed -nE 's|.*(https://app\.asana\.com.*)|\1|p' \
		| uniq
}

get_task_id() {
	local url="$1"
	local task_id
	task_id="$(perl -pe 's|.*https://app.asana.com/0/[0-9]+/([0-9]+)(?:/f)?|\1|; \
                s|.*https://app.asana.com/1/[0-9]+(?:/[0-9a-z/]*)?/task/([0-9]+)(:?/[0-9a-z/]*)?(?:\?focus=true)?|\1|; \
                s|.*https://app.asana.com/1/[0-9]+/inbox/[0-9]+/item/([0-9]+)/story/([0-9]+)(?:\?focus=true)?|\1|' <<< "$url")"
	if [[ -n "$task_id" ]]; then
		local http_code
		http_code="$(curl -fLSs "${asana_api_url}/tasks/${task_id}?opt_fields=gid" \
			-H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}" \
			--write-out '%{http_code}' \
			--output /dev/null)"
		if [[ "$http_code" -eq 200 ]]; then
			echo "${task_id}"
		else
			echo ""
		fi
	fi
}

construct_this_release_includes() {
	if [[ -n "${task_ids[*]}" ]]; then
		printf '%s' '<ul>'
		for task_id in "${task_ids[@]}"; do
			printf '%s' "<li><a data-asana-gid=\"${task_id}\"/></li>"
		done
		printf '%s' '</ul>'
	fi
}

main() {
	# 1. Find last internal release tag (last internal release is the second one, because the first one is the release that's just created)
	local last_release_tag
	last_release_tag="$(gh api repos/:owner/:repo/releases?per_page=25 --jq '[.[] | select(.tag_name | endswith("+macos"))][1].tag_name')"

	# 2. Convert Asana task URLs from git commit messages to task IDs
	local task_ids=()
	while read -r line; do
		local task_id
		task_id="$(get_task_id "$line")"
		if [[ -n "$task_id" ]]; then
			task_ids+=("$task_id")
		fi
	done <<< "$(find_task_urls_in_git_log "$last_release_tag")"

	# 3. Construct a HTML list of task IDs
	local tasks_list
	tasks_list="$(construct_this_release_includes)"
	local escaped_tasks_list="${tasks_list//\"/\\\"}"
	echo "$escaped_tasks_list"
}

main
