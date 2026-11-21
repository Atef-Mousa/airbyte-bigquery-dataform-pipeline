// Raw tables landed in BigQuery by Airbyte
["customers", "products", "orders", "order_items"].forEach((name) =>
  declare({
    schema: "raw",
    name: name,
  })
);
