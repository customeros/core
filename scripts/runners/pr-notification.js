import * as core from '@actions/core';
import * as github from '@actions/github';
import fetch from 'node-fetch';

async function run() {
  try {
    const { eventName, payload } = github.context;
    const pr = payload.pull_request;

    const slackApiToken = process.env.SLACK_API_TOKEN;
    const slackChannelId = process.env.SLACK_CHANNEL_ID;
    const githubToken = process.env.GITHUB_TOKEN;

    if (!slackApiToken || !slackChannelId || !githubToken) {
      throw new Error('Missing required environment variables.');
    }

    const REACTIONS = {
      APPROVED: 'white_check_mark',
      MERGED: 'partymerge',
      CLOSED: 'x',
      COMMENT: 'eyes'
    };

    const existingMessage = await findPrMessage(pr.html_url, slackChannelId, slackApiToken);
    const action = determineAction(eventName, payload, pr);

    if (action === 'opened') {
      const newMessage = await postNewMessage(pr, slackChannelId, slackApiToken, githubToken);
      if (newMessage) {
        await updateReactions(newMessage, action, REACTIONS, slackApiToken);
      }
    } else if (existingMessage && action) {
      await updateReactions(existingMessage, action, REACTIONS, slackApiToken);
    }

  } catch (error) {
    core.setFailed(`Action failed: ${error.message}`);
  }
}

function determineAction(eventName, payload, pr) {
  if (eventName === 'pull_request') {
    if (payload.action === 'opened' || payload.action === 'ready_for_review') return 'opened';
    if (payload.action === 'synchronize') return 'synchronize';
    if (payload.action === 'closed') return pr.merged ? 'merged' : 'closed';
  }

  if (eventName === 'pull_request_review' && payload.review?.state === 'approved') {
    return 'approved';
  }

  if (eventName === 'issue_comment' && payload.issue?.pull_request) {
    return 'commented';
  }

  return '';
}

async function findPrMessage(prUrl, channelId, token) {
  try {
    const response = await fetch(`https://slack.com/api/conversations.history?channel=${channelId}&limit=20`, {
      headers: { Authorization: `Bearer ${token}` }
    });

    const data = await response.json();
    if (data.ok && data.messages?.length > 0) {
      const match = data.messages.find(msg => msg.text?.includes(prUrl));
      if (match) return { ts: match.ts, channel: channelId };
    }

    return null;
  } catch (err) {
    console.error('Error finding PR message:', err.message);
    return null;
  }
}

async function postNewMessage(pr, channelId, token, githubToken) {
  try {
    const userResponse = await fetch(`https://api.github.com/users/${pr.user.login}`, {
      headers: {
        'Accept': 'application/vnd.github.v3+json',
        'Authorization': `token ${githubToken}`
      }
    });

    const userData = await userResponse.json();
    const displayName = userData.name || pr.user.login;
    const repoName = github.context.repo.repo;

    const message = `\`${repoName}\` <${pr.html_url}|${pr.title}>`;

    const response = await fetch('https://slack.com/api/chat.postMessage', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        channel: channelId,
        text: message,
        unfurl_links: false,
        unfurl_media: false,
        username: displayName,
        icon_url: pr.user.avatar_url
      }),
    });

    const data = await response.json();
    if (!data.ok) throw new Error(`Failed to post message: ${data.error}`);

    return { ts: data.ts, channel: data.channel || channelId };
  } catch (err) {
    console.error('Error posting Slack message:', err.message);
    return null;
  }
}

async function updateReactions(message, action, REACTIONS, token) {
  try {
    const res = await fetch(`https://slack.com/api/reactions.get?channel=${message.channel}&timestamp=${message.ts}`, {
      headers: { Authorization: `Bearer ${token}` }
    });

    const data = await res.json();
    const currentReactions = data.ok && data.message?.reactions
      ? data.message.reactions.map(r => r.name)
      : [];

    switch (action) {
      case 'commented':
        if (!currentReactions.includes(REACTIONS.COMMENT)) {
          await addReaction(message, REACTIONS.COMMENT, token);
        }
        break;
      case 'approved':
        if (!currentReactions.includes(REACTIONS.APPROVED)) {
          await addReaction(message, REACTIONS.APPROVED, token);
        }
        break;
      case 'merged':
        if (!currentReactions.includes(REACTIONS.MERGED)) {
          await addReaction(message, REACTIONS.MERGED, token);
          await removeIfExists(message, REACTIONS.APPROVED, currentReactions, token);
          await removeIfExists(message, REACTIONS.CLOSED, currentReactions, token);
          await removeIfExists(message, REACTIONS.COMMENT, currentReactions, token);
        }
        break;
      case 'closed':
        if (!currentReactions.includes(REACTIONS.CLOSED) && !currentReactions.includes(REACTIONS.MERGED)) {
          await addReaction(message, REACTIONS.CLOSED, token);
        }
        break;
    }
  } catch (err) {
    console.error('Error updating reactions:', err.message);
  }
}

async function addReaction({ channel, ts }, emoji, token) {
  try {
    const res = await fetch('https://slack.com/api/reactions.add', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ channel, name: emoji, timestamp: ts }),
    });

    const data = await res.json();
    if (!data.ok) console.error(`Failed to add reaction "${emoji}": ${data.error}`);
  } catch (err) {
    console.error(`Error adding reaction "${emoji}":`, err.message);
  }
}

async function removeIfExists(message, emoji, currentReactions, token) {
  if (currentReactions.includes(emoji)) {
    await removeReaction(message, emoji, token);
  }
}

async function removeReaction({ channel, ts }, emoji, token) {
  try {
    const res = await fetch('https://slack.com/api/reactions.remove', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ channel, name: emoji, timestamp: ts }),
    });

    const data = await res.json();
    if (!data.ok) console.error(`Failed to remove reaction "${emoji}": ${data.error}`);
  } catch (err) {
    console.error(`Error removing reaction "${emoji}":`, err.message);
  }
}

// Run immediately when executed
run();
