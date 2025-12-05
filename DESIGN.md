# Design Notes – Salesforce Weather Service

This file is just a short summary of how I designed the solution and why.

---

## 1. Code Structure

I kept the code in three main layers:

- WeatherApiClient  
  Handles the HTTP call to OpenWeather and JSON parsing. It doesn’t know anything about Salesforce objects.

- WeatherService  
  Contains the business logic: reads Location__c, writes WeatherInfo__c, and returns a simple DTO for the LWC.

- weatherDisplay (LWC) 
  The UI component that only talks to `WeatherService` and never directly to the external API.

This separation makes it easier to:

- Test the API client in isolation (using HttpCalloutMock).
- Reuse WeatherService from other places in the future (e.g. batch jobs).
- Keep the LWC simple and focused on UI.

For error handling, I use:

- WeatherException in WeatherApiClient for integration-specific issues (missing config, non-200 responses, etc.).
- WeatherService catches those and rethrows AuraHandledException so the LWC can show a friendly message.  
- I also use guard checks (e.g. missing location Id, missing latitude/longitude) to fail fast with clear errors.

---

2. OpenWeather Integration & Configuration

For the integration I used a few standard Salesforce patterns:

- Named Credential (OpenWeather) 
  This avoids hard-coding the base URL in Apex and makes it easy to change later.

- Custom Metadata (Weather_Config__mdt)  
  Stores:
  - ApiKey__c – OpenWeather API key  
  - Units__c – metric (Celsius) or imperial (Fahrenheit)  
  - Lang__c – response language (e.g. en)  

Benefits:

- No secrets in code or in the repo.
- Different environments (sandbox vs prod) can use different keys/units without code changes.

The client only calls the documented endpoint:


/data/2.5/weather?lat={lat}&lon={lon}
The JSON response is mapped to typed Apex classes (CurrentWeatherResponse, Main, Weather, etc.), instead of generic maps, so it’s easier to work with and safer at compile time.

3. Custom Object Design
Location__c
Location__c stores the main info about a place:

Name

Latitude__c, Longitude__c

Last_Weather_Updated__c

Last_Weather_Status__c

The coordinates are the key for calling OpenWeather.
They are more precise than a city name and avoid issues with duplicates or different languages.

WeatherInfo__c
WeatherInfo__c stores one snapshot of weather data:

Temperature, humidity, pressure, wind speed

Text description and icon code

RetrievedAt__c – when the API call happened

RawResponse__c – full JSON (optional, useful for debugging)

IsLatest__c – marks the current record for that location

This lets me:

Keep Location__c small and focused.

Keep history of weather readings if needed.

Easily query the latest record for a location using the IsLatest__c flag.

4. LWC & UI Design
The LWC is called weatherDisplay and is only intended for the Location__c record page.

I used standard Lightning base components so it fits nicely with SLDS:

lightning-card as the container.

lightning-button for the Refresh / Get Weather Details action.

lightning-spinner while the callout is running.

Toast messages (ShowToastEvent) for success and errors.

Behaviour:

On page load, it calls getLatestWeatherForLocation (cacheable) to show whatever is already stored in Salesforce without hitting the external API.

When the user clicks Refresh, it calls refreshWeatherForLocation, which triggers the callout and updates the stored data.

It shows:

Location name

Temperature, description

Humidity, wind speed

Last retrieved time and status

I also handle four UI states:

Loading

Error (with a clear message)

Data available

No data yet (prompt to click Refresh)

5. Async / Scalability
For a single record, the user-driven refresh is fine.
For many locations, I added an asynchronous path:

WeatherBatchJob
Implements Database.Batchable<SObject> and Database.AllowsCallouts.
It:

Queries Location__c records that have coordinates.

Calls the same WeatherService.createWeatherInfo logic in bulk.

Updates locations and their latest weather info.

WeatherScheduler
Implements Schedulable and simply launches the batch. It can be scheduled (e.g. nightly or hourly) from Setup.

This means the design can scale from a few locations to many, without changing the UI.

6. Testing
I wrote tests for both the integration and the service layer.

WeatherApiClientTest

Uses HttpCalloutMock to simulate OpenWeather responses.

Covers success and error cases (e.g. non-200 status).

Checks that JSON is deserialized correctly into CurrentWeatherResponse.

WeatherServiceTest

Creates test Location__c and WeatherInfo__c records.

Mocks the callouts and verifies that:

refreshWeatherForLocation creates a WeatherInfo__c, sets IsLatest__c, and updates the location fields.

getLatestWeatherForLocation returns the expected DTO.

This gives good coverage of the main paths and shows that the integration works without hitting the real API during tests.

7. Possible Next Steps (Not Implemented Here)
A few improvements I would consider if this was a real project:

Geocoding
Use OpenWeather’s Geocoding API (or another provider) to automatically fill Latitude__c and Longitude__c from Location__c.Name, so users don’t have to know the coordinates.

Caching
Use Platform Cache to avoid calling the API repeatedly for the same location in a short period of time.

Richer UI
Display the OpenWeather icons using IconCode__c, and maybe add forecast data (e.g. 5day/3hour forecast) if needed.

For the technical test, I focused on the current weather for a location use case, with a clean structure that can be extended later.
