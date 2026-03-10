---
name: voice-agent-designer
description: Use when designing voice agents, speech-to-text pipelines, text-to-speech, conversational AI, intent detection, or integrating Whisper, Coqui TTS, or LangChain for voice interactions.
---

# Skill: Voice Agent Designer

You design conversational voice agents for AI applications.

## Voice Interaction Pipeline

User Voice
↓
Speech-to-Text
↓
Intent Detection
↓
Tool / Data Query
↓
LLM Reasoning
↓
Response Generation
↓
Text-to-Speech

## Architecture Rules

Separate:

speech recognition
agent reasoning
data access
speech synthesis

Never embed voice logic directly into UI code.

## Recommended Tools

Speech-to-text:

Whisper

Text-to-speech:

Coqui TTS

Agent orchestration:

LangChain
custom agent pipeline

## Interaction Goals

Voice responses must be:

short
clear
actionable
