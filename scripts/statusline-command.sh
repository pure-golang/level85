#!/bin/sh
# Claude Code status line — compact format

input=$(cat)

# Context usage percentage
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Session (5-hour) rate limit
session_used=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
session_resets=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')

# Weekly (7-day) rate limit
week_used=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
week_resets=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# Nothing to show if no context data
[ -z "$used" ] && exit 0

ctx_int=$(printf '%.0f' "$used")
output="${ctx_int}%"

if [ -n "$session_used" ]; then
  session_used_int=$(printf '%.0f' "$session_used")
  if [ -n "$session_resets" ]; then
    now=$(date +%s)
    remaining_secs=$((session_resets - now))
    if [ "$remaining_secs" -le 0 ]; then
      time_str="resets now"
    else
      remaining_mins=$((remaining_secs / 60))
      remaining_hrs=$((remaining_mins / 60))
      remaining_mins_part=$((remaining_mins % 60))
      if [ "$remaining_hrs" -gt 0 ]; then
        time_str="${remaining_hrs}h${remaining_mins_part}m"
      else
        time_str="${remaining_mins}m"
      fi
    fi
    output="${output} :: ${session_used_int}% (${time_str})"
  else
    output="${output} :: ${session_used_int}%"
  fi
fi

if [ -n "$week_used" ]; then
  week_used_int=$(printf '%.0f' "$week_used")
  if [ -n "$week_resets" ]; then
    now=$(date +%s)
    remaining_secs=$((week_resets - now))
    if [ "$remaining_secs" -le 0 ]; then
      week_time_str="resets now"
    else
      remaining_mins=$((remaining_secs / 60))
      remaining_hrs=$((remaining_mins / 60))
      remaining_days=$((remaining_hrs / 24))
      remaining_hrs_part=$((remaining_hrs % 24))
      if [ "$remaining_days" -gt 0 ]; then
        week_time_str="${remaining_days}d${remaining_hrs_part}h"
      else
        week_time_str="${remaining_hrs}h"
      fi
    fi
    output="${output} :: ${week_used_int}% (${week_time_str})"
  else
    output="${output} :: ${week_used_int}%"
  fi
fi

printf '%s' "$output"