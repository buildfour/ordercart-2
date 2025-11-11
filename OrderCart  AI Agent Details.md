# OrderCart: AI Agent Details Document

This document details the three core AI Agents built using Google's Agent Development Kit (ADK) that power the essential workflows of the **OrderCart** application. These agents operate collaboratively, passing structured data (Order objects) between them to achieve validation, processing, and exception resolution.

## 1. The Intake & Validation Agent

**(Handles: Automated Order Capture, Order Validation Rules)**

### A. Core Function

This agent is the **System Gateway**. Its primary role is to receive incoming raw order data from all sources (CSV upload, email sync, manual entry), normalize the data format, and apply initial quality checks to determine if the order is safe to enter the main processing pipeline.

### B. ADK Implementation Structure

| Component | Description |
| :--- | :--- |
| **Agent ID** | `ADK-001-IntakeValidator` |
| **System Persona** | The Scrutinizing Clerk / Data Normalizer |
| **Input Schema** | Raw, unstructured order data (JSON, CSV, or Text strings). |
| **Output Schema** | Structured `Order` object (`status: 'New'` or `status: 'Exception'`) |
| **Core Tools/Actions** | `NormalizeData(rawData)`, `ApplyValidationRules(orderData)`, `CheckForDuplicates(orderId)`. |

### C. Core Logic & Implementation Notes

1. **Normalization (`NormalizeData`):** Converts various input fields (e.g., `address1`, `addr_line_1`) into a single, standardized internal data model (`streetAddress`). It parses product lists, ensuring product SKUs are valid against a local cache.

2. **Validation Check (`ApplyValidationRules`):** This is the central function. It runs a configurable sequence of checks based on the rules defined by the user (Feature 4).

   * **Result:** If all checks pass, the agent adds the order to the main Order Collection with `status: 'Validated'` and passes the ID to Agent 2 (`Processor`).

   * **Result:** If any *critical* rule fails (e.g., payment issue, invalid SKU), it sets the `status: 'Exception'`, logs the specific errors, and passes the ID to Agent 3 (`ExceptionHandler`).

3. **Duplicate Detection (`CheckForDuplicates`):** Uses customer metadata (email, name, address) and order details (product list, price) to flag potential duplicates before insertion. If a high-confidence duplicate is found, it is routed straight to Agent 3 (`ExceptionHandler`).

---

## 2. The Fulfillment Processor Agent

**(Handles: Real-time Order Status Tracking, Batch Processing)**

### A. Core Function

This agent manages the mid-flow status of orders. Its primary role is to monitor the **Validated** queue, categorize orders for efficiency (batching), and execute bulk actions like status updates and notification triggering, managing the state transitions from **Validated** up to **Shipped**.

### B. ADK Implementation Structure

| Component | Description | |
| :--- | :--- | :--- |
| **Agent ID** | `ADK-002-FulfillmentProcessor` | |
| **System Persona** | The Workflow Manager / Assembly Line Foreman | |
| **Input Schema** | Structured `Order` object with `status` values from `Validated` to `Packed`. | |
| **Output Schema** | Updated `Order` object (e.g., `status: 'Shipped'`), structured `Batch` object. | |
| **Core Tools/Actions** | `SuggestBatch(validatedOrders)`, `ExecuteBulkAction(batchId, action)`, `TriggerCommunication(orderId, templateName)`. | |

### C. Core Logic & Implementation Notes

1. **Batch Suggestion (`SuggestBatch`):** This function is constantly analyzing the `Validated` queue. It uses heuristics (time-based, geographical, or product similarity) to group orders (Feature 5). It generates and stores potential `Batch` objects in a dedicated collection.

   * *Implementation Note:* The agent uses a simple clustering algorithm (like K-Means on geo-coordinates) or a dictionary-based grouping (e.g., `ordersByProduct['SKU-100']`).

2. **State Management:** Listens for human-triggered events (e.g., drag-and-drop on the Kanban board). When a user changes an order's status, the agent validates the transition (e.g., prevents skipping from **Validated** directly to **Shipped**).

3. **Action Execution (`ExecuteBulkAction`):** When a user initiates a batch action (like "Mark All Shipped"), this agent orchestrates the database updates for all orders in the batch and immediately triggers the `TriggerCommunication` action for each.

4. **Communication Triggering (`TriggerCommunication`):** While Agent 3 (Handler) often generates the content, Agent 2 is responsible for calling the API hook to send the pre-generated message (confirmation, shipping update, etc.) to the customer (Feature 7).

---

## 3. The Exception Handler & Communication Agent

**(Handles: Error Detection & Smart Alerts, Exception Handling Workflow, Customer Communication Templates)**

### A. Core Function

This is the advanced reasoning agent. It specializes in processing orders that have failed validation (from Agent 1) or encountered issues mid-flow (from Agent 2). It performs root cause analysis, suggests resolutions, and generates tailored, professional customer communications.

### B. ADK Implementation Structure

| Component | Description | |
| :--- | :--- | :--- |
| **Agent ID** | `ADK-003-ExceptionHandler` | |
| **System Persona** | The Troubleshooter / Customer Service Specialist | |
| **Input Schema** | Structured `Order` object with `status: 'Exception'` and an `errors` array. | |
| **Output Schema** | Updated `Order` object, Human-readable error summaries, Generated Text Content. | |
| **Core Tools/Actions** | `AnalyzeError(errorArray)`, `SuggestResolution(analysis)`, `GenerateCustomerMessage(template, context)`. | |

### C. Core Logic & Implementation Notes

1. **Error Analysis (`AnalyzeError`):** Takes the raw list of validation failures from Agent 1 or runtime errors from Agent 2. It uses an internal LLM call (via ADK) to categorize the problem (e.g., "Address Issue," "Stock Conflict," "Policy Breach") and generate a concise, human-readable summary for the Exception Queue Dashboard (Feature 3, 6).

   * *System Instruction:* "You are a problem solver. Given a list of technical errors, categorize the issue and provide a one-sentence, non-technical suggestion for the user."

2. **Resolution Suggestion (`SuggestResolution`):** Based on the analysis, this function recommends the next best action (e.g., "Correct Address in CRM," "Contact Customer for New Payment Method," or "Waitlist Order"). This powers the "One-click resolution suggestions" and guided workflows (Feature 6).

3. **Communication Generation (`GenerateCustomerMessage`):** This is the communication engine (Feature 7). It receives the template name and context (order data, error type) and uses an internal LLM call to draft a personalized, professional message tailored to the situation.

   * *Example Prompt:* "Draft a professional email to customer $\text{Name}$ for order $\text{ID}$. The issue is: $\text{Analyzed Error}$. Use a sympathetic and proactive tone. The message must state that the order is on hold."

   * *Implementation Note:* This ensures high-quality, non-repetitive responses to customer issues, improving service consistency.

---

## Agent Workflow Diagram

The three agents work together in a sequential and looped dependency model:

1. **New Order** $\xrightarrow{\text{Data}} \text{Agent 1 (Intake)}$

2. **Order** $\xrightarrow{\text{Validated}} \text{Agent 2 (Processor)}$

3. **Order** $\xrightarrow{\text{Exception}} \text{Agent 3 (Handler)}$

4. **Agent 3 (Handler)** $\xrightarrow{\text{Resolved}} \text{Agent 2 (Processor)}$

5. **Agent 2 (Processor)}** $\xrightarrow{\text{Communication Request}} \text{Agent 3 (Handler)}$

This workflow ensures Agent 1 acts as the gate, Agent 2 manages successful flow, and Agent 3 is the dedicated cleanup/communication specialist.

### Deployment Note

All three ADK Agents are intended to be deployed as separate, lightweight services on **Cloud Run** containers, communicating primarily through shared state in a centralized database (Firestore) and internal Pub/Sub messages (e.g., "ORDER\_VALIDATED", "ORDER\_NEEDS\_REVIEW") for real-time task hand-off.