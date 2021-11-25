# waltti-apc-pilot-spec

Describe technical specifications for the APC pilot by Waltti.

[apc-from-vehicle.schema.json](./apc-from-vehicle.schema.json) contains the preliminary [JSON Schema](https://json-schema.org/) that validates the data serialization for the pilot.
All APC pilot systems in the vehicles must conform to this schema.

Run

```sh
./validate-schema.sh
```

to validate the schema.

[preferred-per-door-example.json](./preferred-per-door-example.json) contains a JSON example of data that we expect to see in the backend.
All in-vehicle APC system vendors in the pilot are strongly encouraged to send data according to this example.

Run

```sh
./validate-preferred-per-door-example.sh
```

to validate the preferred example.
You can modify the script for your needs.
