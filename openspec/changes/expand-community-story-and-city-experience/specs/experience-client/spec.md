## ADDED Requirements

### Requirement: Story ledger owns reconstruction
The client SHALL place every reconstruction or complete-story action inside the story ledger and SHALL NOT render a separate reconstruction card in the journey detail body. The ledger SHALL show the action only when the server-provided reconstruction state permits it and SHALL distinguish an unfinished reconstruction from an already completed story.

#### Scenario: Reconstruction becomes available
- **WHEN** all required fragments are collected and reconstruction is unlocked
- **THEN** opening the story ledger reveals a “拼回完整故事” action after the collected entries while the journey detail body remains free of a reconstruction card

#### Scenario: Reconstruction is completed
- **WHEN** the traveler has already completed reconstruction
- **THEN** the ledger offers a complete-story review action instead of asking the traveler to reconstruct again

#### Scenario: Reconstruction remains locked
- **WHEN** required fragments are still missing
- **THEN** the ledger shows collection progress without an enabled reconstruction action

### Requirement: Concise journey story heading
The active journey SHALL present the current story theme without the redundant “你正在追问” label and SHALL keep the node rail, narration, optional memory, test progression, and node discussion in their existing functional order.

#### Scenario: Open an active journey
- **WHEN** a traveler opens or resumes an active fragmented journey
- **THEN** the page does not render “你正在追问” and still communicates the central story theme without implying that the traveler asked a question
