# Claude Skill Router

This router determines which engineering skill Claude should apply depending on the user's request.

Claude must analyze the task and automatically activate the appropriate skill modules.

---

## Architecture Tasks

If the request involves:

* system design
* architecture
* component planning
* service design
* scalability

Activate:

@skills/ai-system-architect.md
@skills/software-design-principles.md

---

## Computer Vision Tasks

If the request involves:

* video processing
* pose detection
* frame extraction
* image analysis
* CV model pipelines

Activate:

@skills/computer-vision-pipeline.md
@skills/ai-performance-engineer.md

---

## Machine Learning Tasks

If the request involves:

* model training
* dataset preparation
* ML pipelines
* evaluation metrics

Activate:

@skills/ml-engineer.md
@skills/ai-experiment-designer.md

---

## Multimodal AI Tasks

If the request involves:

* video + audio
* LLM reasoning with vision
* multimodal agents

Activate:

@skills/multimodal-ai-systems.md

---

## Voice Agent Tasks

If the request involves:

* voice assistants
* speech-to-text
* text-to-speech
* conversational agents

Activate:

@skills/voice-agent-designer.md

---

## Frontend / UI Tasks

If the request involves:

* dashboard design
* UI components
* analytics visualization
* responsive design

Activate:

@skills/ai-product-ui-designer.md

---

## Data Pipeline Tasks

If the request involves:

* dataset processing
* data storage
* analytics pipelines

Activate:

@skills/ai-data-engineer.md

---

Claude should always combine relevant skills when tasks overlap.
