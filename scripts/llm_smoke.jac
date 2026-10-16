"""P0.4: prove the model returns typed output for a text call and for an image call.

Run with:  jac run --no-serve scripts/llm_smoke.jac
(plain `jac run` would serve the web app instead of running the script)
"""

import from jaclang.byllm.lib { Image }

obj SmokeItem {
    has name: str,
        quantity: int;
}
sem SmokeItem.name = "Product name as the customer wrote it.";
sem SmokeItem.quantity = "How many units the customer asked for.";

obj SmokeOrder {
    has items: list[SmokeItem];
}
sem SmokeOrder.items = "Every product and quantity requested in the message.";

def parse_text(message: str) -> SmokeOrder by llm(temperature=0.0);
sem parse_text = "Extract the products and quantities from a wholesale order message written in English or Swahili.";
sem parse_text.message = "The customer's order message.";

def describe_image(img: Image) -> str by llm(temperature=0.0);
sem describe_image = "Read this photo of a handwritten shopping list and write out each line you can read.";
sem describe_image.img = "A photo of a handwritten order list.";

with entry {
    order = parse_text("Niletee Rina 5 carton na Jogoo 10 bale");
    print("TEXT:", [(i.name, i.quantity) for i in order.items]);
    text = describe_image(Image("tests/fixtures/images/sample_list.jpg"));
    print("IMAGE:", text);
}
