import os, base64, json
from openai import OpenAI

client = OpenAI()

model_name="gpt-4o"
reasoning_model_name="o4-mini"

# Simple text prompt and response...
response = client.responses.create(
  model=model_name,
  input="Who is this Frank Kane guy on Udemy anyhow?",
  instructions="Always talk like a pirate."
)

print("\nFull response:")
parsed = response.to_dict()
print(json.dumps(parsed, indent=2))

print("\nText only:")
print(response.output[0].content[0].text)

# Image input, text output
file_response = client.files.create(file=open("bird.png", "rb"), purpose="vision")
response = client.responses.create(
    model=model_name,
    input=[{
        "role": "user",
        "content": [
            {"type": "input_text", "text": "What kind of bird is this?"},
            {
                "type": "input_image",
                "file_id": file_response.id,
            },
        ],
    }],
)

print("\nImage query:")
print(response.output_text)

#Using a built-in tool
response = client.responses.create(
    model=model_name,
    tools=[{"type": "web_search_preview"}],
    input="What is the current stock price of UDMY?"
)

print("\nUsing the built-in web search tool:")
print(response.output_text)

#Conversation state (chaining responses together)

print("\nConversation state demo:")
response = client.responses.create(
    model=model_name,
    input="What is 5 + 4?",
)
print(response.output_text)

second_response = client.responses.create(
    model=model_name,
    previous_response_id=response.id,
    input="Add 3 more to that.",
)
print(second_response.output_text)


#MCP demo
resp = client.responses.create(
    model=model_name,
    tools=[
        {
            "type": "mcp",
            "server_label": "gitmcp",
            "server_url": "https://gitmcp.io/pytorch/pytorch",
            "require_approval": "never",
        },
    ],
    input="How do I compile PyTorch with CUDA support?",
)

print("\nMCP (model context protocol) usage:")
print("\nFull response:")
parsed = resp.to_dict()
print(json.dumps(parsed, indent=2))
print("\nOutput only:")
print(resp.output_text)

#Reasoning demo
prompt = """
Create a retirement plan for a 50-year-old male of average health in the United States.
Assume he has the maximum social security benefits, and that the expected reduction in benefits in 2033 occurs.
His current liquid assets saved are $1 million. How much more must he save each year in order to retire at age 
age 60, or age 65? His retirement goal is to survive until death on $100K per year, adjusted for inflation.
"""

response = client.responses.create(
    model=reasoning_model_name,
    reasoning={"effort": "medium"}, # For a reasoning summary, you would add "summary": "auto" - but this requires org. verification
    input=[
        {
            "role": "user", 
            "content": prompt
        }
    ]
)

print("\nReasoning demo:")
print("\nFull response:")
parsed = response.to_dict()
print(json.dumps(parsed, indent=2))
print("\nOutput text only:")
print(response.output_text)