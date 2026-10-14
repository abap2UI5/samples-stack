# 10 — AI / LLM

*[← all packages](https://github.com/abap2UI5/samples-stack/blob/main/README.md)*

An abap2UI5 app that talks to a **large language model**: a chat, and a table of
business data summarized by AI. The app stays what every abap2UI5 app is — one
ABAP class, a view, a few events — and the model is reached the way ABAP reaches
any HTTPS service: through a destination of the system.

The samples know one small interface, `Z2UI5_IF_SMPS_LLM` — a conversation in,
the answer out — and never which vendor is behind it. Three implementations ship
with the package:

| Provider | Class | Wire format |
|---|---|---|
| Anthropic Messages API | `Z2UI5_CL_SMPS_LLM_CLAUDE` | `POST /v1/messages`, headers `x-api-key` and `anthropic-version: 2023-06-01`, body `{model, max_tokens, system, messages}`, answer = the first text block of `content` |
| OpenAI-compatible Chat Completions | `Z2UI5_CL_SMPS_LLM_OPENAI` | `POST /v1/chat/completions`, `Authorization: Bearer`, body `{model, max_completion_tokens, messages}`, answer = `choices[0].message.content` — OpenAI itself or any compatible server or gateway |
| SAP ABAP AI SDK (ISLM) | `Z2UI5_CL_SMPS_LLM_ISLM` | no HTTP of its own: `cl_aic_islm_compl_api_factory` and an intelligent scenario, which reaches the generative AI hub in SAP AI Core |

Which one answers is a **setting**, not code. Endpoint, model and key are never
written into a class: the endpoint is a destination, and model, token limit,
request path and key are one row of the table `Z2UI5_T_SMPS_LLM`, maintained
with the settings sample.

## What you need

**Release:** Cloud + Standard ≥ 7.40 SP08.

**Branch:** [`10-ai-llm`](https://github.com/abap2UI5/samples-stack/tree/10-ai-llm)
— this package alone, without the other nine on your system.

**An endpoint the system can reach over HTTPS**, and that is the one step this
package cannot take for you. The two stacks release different HTTP clients, so
the package carries one small transport class per stack — each activates on its
own stack only, and the samples pick whichever is there at runtime. An
activation error for the other one is expected:

| Your system | Transport | Set up |
|---|---|---|
| **Standard** (on-premise) | `Z2UI5_CL_SMPS_LLM_SM59` ([`src/10/01`](01)) — `cl_http_client=>create_by_destination` | an **SM59** destination of type G: target host `api.anthropic.com`, `api.openai.com` or your gateway, port 443, SSL active, path prefix empty. Import the endpoint's certificate chain into the SSL client PSE in `STRUST`, and name the proxy if the system needs one |
| **ABAP Cloud** | `Z2UI5_CL_SMPS_LLM_CLOUD` ([`src/10/02`](02)) — `cl_web_http_client_manager` on `cl_http_destination_provider=>create_by_cloud_destination` | a destination in the **BTP subaccount** (type HTTP, URL = scheme and host only, NoAuthentication), and in the ABAP environment the communication arrangement for **`SAP_COM_0276`** (destination service integration) |
| **ABAP AI SDK** present | `Z2UI5_CL_SMPS_LLM_ISLM` ([`src/10/03`](03)) | SAP AI Core connected and an **intelligent scenario** with a model set up in the ISLM apps. Only where SAP ships the SDK — elsewhere this class does not activate, and the settings say so |

Then start `?app_start=z2ui5_cl_smps_app_013` and fill in:

- **Provider** — Anthropic Messages API, OpenAI-compatible, or ABAP AI SDK.
- **Destination** — the SM59 destination, the BTP destination, or for the ABAP AI
  SDK the id of the intelligent scenario.
- **Model** — the model id exactly as your provider's documentation spells it.
  There is deliberately no default: which model you may use, and pay for, is your
  decision. Empty for the ABAP AI SDK, where the scenario names the model.
- **Max Tokens** — the answer's limit. Current models think before they answer
  and that counts against it, so a limit that is too small returns no text at
  all — the samples then say so instead of showing an empty answer.
- **Request Path** — empty for `/v1/messages` and `/v1/chat/completions`. Fill it
  for a compatible server that lives elsewhere (Azure OpenAI is one).
- **API Key** — sent as `x-api-key` (Anthropic) or `Authorization: Bearer`
  (OpenAI-compatible). See below before you type one.

**Test Connection** sends one message with what the form says, saved or not, and
shows the answer or the provider's error message.

### Where the key lives

SM59 and a communication system know user/password, OAuth and certificates — not
an API-key header. So the key has two possible homes:

1. **A gateway in front of the provider adds it** (SAP API Management, a reverse
   proxy). The destination points at the gateway and the API Key field stays
   empty. This is the place for anything beyond a sandbox.
2. **The configuration row.** The settings screen is write-only for it: a stored
   key is never sent back to a browser. It is still a plain table field, readable
   by anybody with a data browser — so restrict access to `Z2UI5_T_SMPS_LLM`, and
   restrict who may start `Z2UI5_CL_SMPS_APP_013`, because any user who reaches
   it can change where your prompts go.

## The samples

| Sample | Shows |
|---|---|
| [`013`](z2ui5_cl_smps_app_013.clas.abap) | the settings — provider, destination, model, key — and a connection test with one press |
| [`014`](z2ui5_cl_smps_app_014.clas.abap) | a chat: FeedInput and FeedListItems, the conversation sent with every question, the answer fetched in a second roundtrip behind a busy feed. The screen of `Z2UI5_CL_SMP_APP_540` in [abap2UI5/samples](https://github.com/abap2UI5/samples), answered by a real model instead of rules |
| [`015`](z2ui5_cl_smps_app_015.clas.abap) | a table of sales figures and *Summarize with AI*: the rows go to the model as context and its summary comes back into a panel — with the prompt hygiene a real app needs: at most 50 rows, only the columns the question needs (no internal keys, no user names), the data fenced off and declared as data. The real-model counterpart of `Z2UI5_CL_SMP_APP_541` in [abap2UI5/samples](https://github.com/abap2UI5/samples), which explains a selection with a local provider instead |

Start any of them with `?app_start=z2ui5_cl_smps_app_<no>`, or from the overview
app `?app_start=z2ui5_cl_smps_app_000`. Begin with `013`. Without a configuration
`014` and `015` still start: they show a MessageStrip saying what is missing,
keep their buttons disabled and send nothing.

## How it is built

```
Z2UI5_CL_SMPS_APP_014 / _015      the apps - know Z2UI5_IF_SMPS_LLM only
        |
Z2UI5_CL_SMPS_LLM_FACTORY         reads Z2UI5_T_SMPS_LLM, creates the provider
        |
Z2UI5_CL_SMPS_LLM_CLAUDE          wire format of one API each,
Z2UI5_CL_SMPS_LLM_OPENAI          built and read with Z2UI5_CL_SMPS_LLM_JSON
        |
Z2UI5_IF_SMPS_LLM_HTTP            one POST - created BY NAME, one per stack:
  Z2UI5_CL_SMPS_LLM_SM59          src/10/01, Standard
  Z2UI5_CL_SMPS_LLM_CLOUD         src/10/02, ABAP Cloud

Z2UI5_CL_SMPS_LLM_ISLM            src/10/03 - the ABAP AI SDK, no HTTP of its own
```

- **JSON by hand.** abap2UI5 releases no JSON parser, `/ui2/cl_json` is not
  released for ABAP Cloud and `xco_cp_json` does not exist on 7.40. The request
  body is a string template with every free text escaped; the answer is read by a
  small walker that reads string tokens whole — so a key-like text inside a value
  never matches — and resolves escapes. Only the one field each answer is about is
  read. The same approach as `Z2UI5_CL_SMPS_APP_489`, which writes its payload
  itself.
- **One exception, written for the person fixing the setup.** Everything that
  can go wrong — no configuration, no destination, no connection, an error object
  from the provider — is `Z2UI5_CX_SMPS_LLM`, and the samples show its text in a
  MessageStrip.
- **Nothing static across a stack boundary.** The factory creates the transport
  and the ISLM provider by name, so the classes that do activate never depend on
  the ones that cannot.

## Where to go next

- [`09` Launchpad](https://github.com/abap2UI5/samples-stack/blob/main/src/09/README.md) — put the chat on a tile.
- [`03` RAP](https://github.com/abap2UI5/samples-stack/blob/main/src/03/README.md) — summarize the travels of a business object
  instead of the demo rows: `Z2UI5_CL_SMPS_APP_015` only needs a table.
