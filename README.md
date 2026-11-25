# Waltti-APC Vehicle Specification: Automatic Passenger Counting Data Collection

Waltti Solutions has an IT system called [Waltti-APC](https://github.com/tvv-lippu-ja-maksujarjestelma-oy/waltti-apc) for collecting automatic passenger counting (APC) data from public transit vehicles.
The data is used for public transit planning and also published in a strongly anonymized manner for passenger information services.

This repository contains the technical specifications for data delivery from the vehicles to the Waltti-APC system.
The text is aimed at a technical audience for implementing the systems running in the vehicles, especially the vendors who create and maintain the onboard counting devices.

## Basic principles

The APC devices are expected to count the people and possibly other objects entering and exiting the vehicles.

Each **counting system**, i.e. the set of counting devices installed in one vehicle, is expected to send its results as soon as possible or at each stop.
A counting system could correspond to a set of three cameras in a three-door bus or one security camera sensor in a vehicle.
Usually only one counting system is installed per vehicle.

Experience has shown that attention to detail in the installation of the physical devices improves the quality of the counting results.
It is in the interest of public transport authorities and operators to make sure that the installations are done properly and professionally.

If several messages are sent per stop, Waltti-APC backend will sum the results per stop.
Therefore it is up to the counting system to decide whether to send each passenger individually or to accumulate the results until departing from the stop.

To ease the life of the vendor, there are no requirements in the API regarding the public transit context.
For example, there are no references to routes or stops in the API.
The counting system does not need GNSS positioning or stop detection.
Waltti-APC gets the stops from the GTFS Realtime vehicle position feed of the public transport authority.

### Timing

Waltti-APC matches each message to a stop by the time when the message arrives at Waltti-APC, not by `tst`.
After the vehicle leaves a stop, Waltti-APC waits about 15 seconds and then closes the counts for that stop.
A message that arrives later is added to a later stop.

Therefore:

- Send the counts for a stop as soon as possible, at the latest 5 seconds after the doors close.
- If nobody boards or alights at a stop, you do not need to send a message.
- Keep the clock of the counting system synchronized, for example with NTP or GNSS time, so that `tst` is correct.

Waltti-APC does not yet match late messages to the correct stop by `tst`.
See [Buffering](#buffering) for messages that are delayed by a connection problem.

### Counting system registration

Waltti-APC accepts the data of a counting system only after the counting system is registered to a vehicle.
The registration connects the `countingSystemId` to the operator and the vehicle number in the vehicle registry of the public transport authority.
The authority or the operator maintains the vehicle registry. Waltti-APC only reads it.
Waltti-APC drops the messages of an unregistered counting system, and the vendor gets no error message.

Agree with the authority or the operator who registers the `countingSystemId` of each counting system, and get it registered before you start to send data.
Do the same before you move a counting system to another vehicle or replace it.

This API has been designed to be compatible with the corresponding [HSL Helsinki Region Transport](https://www.hsl.fi/en) APC API to enable one API specification to serve all of Finland.
If you notice any discrepancies, please contact Waltti.

The delivery from the vehicle must happen over MQTT.
Below are the MQTT and message specifications.

```mermaid
flowchart LR
  vehicle("Vehicle")
  mqttbroker("MQTT broker")
  walttiapc("Waltti-APC")
  vehicle --> mqttbroker
  mqttbroker --> walttiapc
```

## MQTT message contents

Each message is in JSON.

[apc-from-vehicle.schema.json](./apc-from-vehicle.schema.json) contains the [JSON Schema](https://json-schema.org/) that can validate the data sent to Waltti-APC.
It is required that all counting systems adhere to this schema.

The schema is inspired by an existing API from [HSL Helsinki Region Transport](https://www.hsl.fi/en) and by [ITxPT](https://itxpt.org/).
Read the comments in the schema carefully.

[example-message.json](./example-message.json) contains a JSON example of what could be sent to the MQTT broker:

```json
{
  "APC": {
    "schemaVersion": "1-3-0",
    "countingSystemId": "3298a747-c434-4030-b6d7-ab803bd823d2",
    "messageId": "06e64ba5-e555-4e2f-b8b4-b57bc69e8b99",
    "tst": "2023-09-22T10:57:08.647Z",
    "vehiclecounts": {
      "countquality": "regular",
      "doorcounts": [
        {
          "door": "1",
          "count": [
            {
              "class": "adult",
              "in": 3,
              "out": 0
            }
          ]
        },
        {
          "door": "2",
          "count": [
            {
              "class": "adult",
              "in": 1,
              "out": 2
            },
            {
              "class": "pram",
              "in": 1,
              "out": 0
            }
          ]
        }
      ]
    }
  }
}
```

The values in the messages sent from the vehicle should not be cumulative.
The accumulation is done in the Waltti-APC system.
For example, imagine three adults embark through the first door and a message is sent with value `"in": 3`.
Then two more adults embark on the same stop through the same door and another message is sent.
The latter message should have value `"in": 2`, not `"in": 5`.

Other rules for the message contents:

- Include each door at most once in one message, and each `class` at most once for one door.
- Use the same door IDs in all messages of the counting system.
- Count each person once, as `adult`, `child` or `other`.
  Count a pram, a bike or a wheelchair in addition to the person who has it.
  For example, a person who boards with a bike is `{"class": "adult", "in": 1, "out": 0}` and `{"class": "bike", "in": 1, "out": 0}` for the same door.
- Do not add fields that the schema does not define. Waltti-APC drops the whole message if a count item has an unknown field.
- Send only the counts and the IDs that the schema defines. Do not send images, video or personal data.

`schemaVersion` is the version of the message schema. `v1` in the MQTT topic is the version of the API. Waltti will announce schema and API changes to vendors before they take effect.

The `$id` URL of the schema is an identifier only. Use the schema file in this repository.

Run

```sh
./validate-example-message.sh
```

to validate the preferred example.
Give a file path as the first argument to validate your own message.
The scripts need Node.js and npm, and you must run them in the root of this repository.

Run

```sh
./validate-schema.sh
```

to validate the schema itself.

## MQTT topic

Each counting system has its own topic:

```
apc-from-vehicle/<api-version>/fi/waltti/<vendor-id>/<counting-system-id>
```

Replace `<api-version>` with `v1`.

Replace `<vendor-id>` with the vendor ID that Waltti gives you, for example `telia`.

Replace `<counting-system-id>` with the `countingSystemId` described in [apc-from-vehicle.schema.json](./apc-from-vehicle.schema.json).
The topic level and the `countingSystemId` in the payload must be the same.
Do not use `.`, `/`, `+` or `#` in the IDs: the MQTT broker uses them as separators and wildcards.

## Environments and MQTT broker URLs

Each environment has its own MQTT broker to connect to and needs separate credentials.
The credentials are per vendor and per environment.
Make sure you have a way to rotate the credentials in case it is necessary.

Waltti-APC might change the MQTT brokers while retaining the hostname so do not hard code the IP addresses.

### Staging

Initially new vendors and possibly every new counting system will be given access only to the staging environment.

The MQTT broker for the staging environment is at `mqtts-staging.apc.waltti.fi`.

In this environment the data format and the counting system behaviour is checked.

You can both publish and subscribe to your messages in the staging environment.

### Production

Once a counting system has been deemed to function as expected in the staging environment, it can be promoted to production.
In the production environment the counting system results will end up into the hands of the public transit planners and anonymized for public consumption.

The MQTT broker for the production environment is at `mqtts-prod.apc.waltti.fi`.

You can only publish and not subscribe to your messages in the production environment.

## MQTT parameters

### Protocol version

The protocol version used is the [MQTT protocol version 3.1.1 Plus Errata 01](https://docs.oasis-open.org/mqtt/mqtt/v3.1.1/errata01/os/mqtt-v3.1.1-errata01-os-complete.html).
Do not use MQTT 5.0: Waltti-APC has not tested it with counting systems.
Any updates to the protocol version will be communicated clearly.

Do not request QoS 2.
The MQTT brokers support QoS 0 and QoS 1 only, and they answer a QoS 2 message as a QoS 1 message.
Some MQTT client libraries do not handle this.

### Port

Use port `8883` with TLS.

### Authentication

Authenticate with a username and a password.

### Authorization

You will be allowed to act within the topic tree:

```
apc-from-vehicle/v1/fi/waltti/<vendor-id>/#
```

where `<vendor-id>` is described in the section MQTT topic.

### Reconnecting

Reconnect automatically.

This is usually handled by the MQTT client library in the client configuration or in the `connectionLostCallback()` or equivalent.

### QoS

Use QoS 1.

This is usually defined in the arguments for `publish()` or equivalent of the MQTT client library.

With QoS 1, the broker can receive the same message more than once.
When you resend a message, send the same payload to the same topic, byte for byte, with the same `messageId`.
Waltti-APC then removes the duplicate.
Use a new `messageId` only for new counts.

The broker acknowledgment (`PUBACK`) means that the broker received the message.
It does not mean that Waltti-APC accepted the message.
Check the acceptance of your data with Waltti in the staging environment.

### Retained messages

Do not use retained messages for the counts.
Use retained messages only for the connection status, see [Last Will scheme](#last-will-scheme).

This is usually defined in the arguments for `publish()` or equivalent of the MQTT client library.

### Clean session

Set clean session to false, i.e. do not wipe out in-progress message acknowledgments upon reconnecting.

This is usually defined in the arguments for `connect()` or equivalent of the MQTT client library.

### Client Identifier

The Client Identifier (ClientId) names the MQTT session that persists over several TCP connections when "clean session" is set to false.
For example MQTT message acknowledgment is based on ClientId.

Unfortunately the MQTT protocol has a feature that enables a denial-of-service attack on connected clients:
**If any two clients, no matter their credentials, successfully connect with the same ClientId, the broker must disconnect the first connection.**

It is not planned but maybe at some point the MQTT brokers will be consolidated into one and used by consumer-facing services in the future.
At that point no one wants to handle ClientId conflicts.
Therefore the ClientId must be protected from the start.

For each MQTT client/vehicle use a ClientId of the form:

```
<vendor-id>-<random-suffix>
```

where `<vendor-id>` is described in the section MQTT topic and `<random-suffix>` is 10 characters from the range `[0-9A-Za-z]` randomly generated by you for each counting system.

The Waltti-APC brokers accept a ClientId that is longer than the 23 bytes that MQTT 3.1.1 requires a broker to accept.
If your MQTT client library limits the ClientId to 23 bytes, tell Waltti.

Normally there is no need to change `<random-suffix>`.
Do not change `<random-suffix>` unless you are sure all messages from the counting system have been delivered and every message has been fully acknowledged.

Treat `<random-suffix>` as a sensitive secret like a password.

### Last Will scheme

Using Last Will is an easy and cheap investment into your connection debugging pleasures.

Use a connection status topic:

```
apc-from-vehicle/<api-version>/fi/waltti/<vendor-id>/<counting-system-id>/connection-status
```

The section on the MQTT topic explains the topic variables.

When connecting to the broker with the MQTT `CONNECT` message, specify a Last Will UTF-8 message payload `disconnected` into the connection status topic.

Ask broker to send the Last Will as a retained message with QoS 1.

These are usually defined in the arguments for `connect()` or equivalent of the MQTT client library.

When connecting or reconnecting, first send a UTF-8 message `connected at <connected-time>` to the connection status topic.
`<connected-time>` should be created as early as possible when the MQTT (re)connection succeeds.
It must contain an ISO 8601 timestamp with a fixed precision, for example millisecond precision, and with UTC time zone denoted with `Z`, e.g. `2023-09-27T08:29:28.123Z`.

This message should be sent as a retained message with QoS 1, too.

Before a planned disconnect, send a retained message `disconnected` to the connection status topic.
The broker does not send the Last Will after a normal `DISCONNECT`.

This is usually handled in the `connectionSucceededCallback()` or equivalent of the MQTT client library.

### Buffering

To avoid data loss due to power outages or connection problems, it is recommended to persist messages on non-volatile storage until acknowledged by the MQTT broker.

MQTT client libraries will not usually do this for you but will offer the necessary callbacks.

Waltti-APC matches the messages to stops by arrival time, see [Timing](#timing).
A buffered message is added to the stop where the vehicle is when the message arrives, which is usually a wrong stop.
Therefore, after a reconnect:

- Send the buffered messages whose `tst` is at most 15 seconds old.
- Do not send older buffered messages automatically.
  Keep them, for example in a deque or ring buffer that can contain messages for a week, and throw away the oldest messages first if a size limit is reached.
  Contact Waltti if you need to deliver them.

## Onboarding

1. Contact Waltti. Waltti gives you a `<vendor-id>`.
1. Waltti gives you separate credentials for the staging environment through a secure channel.
1. Make sure that each counting system is registered to its vehicle, see [Counting system registration](#counting-system-registration).
1. Send data from a test vehicle to the staging environment. Waltti checks the data format, the matching to stops and the counts.
1. When the data is correct, Waltti gives you the credentials for the production environment.
