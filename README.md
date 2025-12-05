# Salesforce Weather Service (OpenWeatherMap)

Author: Sagar Reddy  
Test: Salesforce Technical Test – Weather Service

1. What this Project.

This project is a small Salesforce app that shows current weather on a custom Location__c record.

- Each Location__c has a name + latitude + longitude.
- When you click a button on the record page, Salesforce calls the OpenWeatherMap API.
- The result is stored in a `WeatherInfo__c` record and shown in a Lightning Web Component.

I focused on:
- Keeping the integration simple but clean.
- Using proper Salesforce patterns (Named Credential, Custom Metadata, Apex service layer, LWC).

---

 2. Data model

 Location__c

Custom object for locations.

Fields I used:

- Name: (standard)
- Latitude__c: (Number 8,5)
- Longitude__c: (Number 8,5)
- Last_Weather_Updated__c: (Date/Time)
- Last_Weather_Status__c: (Text)

 WeatherInfo__c

Custom object for the actual weather data.

Key fields:

- Location__c (Lookup → Location__c)
- Temperature__c
- Description__c
- Humidity__c
- Pressure__c
- WindSpeed__c
- IconCode__c
- RetrievedAt__c
- IsLatest__c (Checkbox)
- RawResponse__c(Long Text Area, optional)

Idea: Location__c is the place, WeatherInfo__c is the reading.

---

 3. Integration setup

3.1 OpenWeather API key

1. Sign up at OpenWeather and get an API key.
2. In Salesforce, I store it in Custom Metadata instead of hard-coding it.

3.2 Named Credential

- Name: OpenWeather
- URL: https://api.openweathermap.org
- Identity: Anonymous
- Auth: None

3.3 Custom Metadata: Weather_Config__mdt

Fields:

- ApiKey__c – your OpenWeather API key
- Units__c – e.g. metric (Celsius) or imperial (Fahrenheit)
- Lang__c – e.g. en

Record example:

- Developer Name: Default
- ApiKey__c: YOUR_REAL_KEY
- Units__c: metric
- Lang__c: en

---

4. Apex classes (short overview)

WeatherApiClient

- Does the actual HTTP call to OpenWeather.
- Uses the Named Credential and Weather_Config__mdt.
- Method: getCurrentWeather(Decimal lat, Decimal lon)
  - Validates lat/lon.
  - Calls /data/2.5/weather.
  - Deserializes JSON into a simple response class.
  - Throws WeatherException if something goes wrong (e.g. 401).

WeatherService

- Used by the LWC and by batch jobs.
- Main methods:
  - getLatestWeatherForLocation(Id locationId)
    - Reads Location__c + latest WeatherInfo__c (IsLatest__c = true).  
    - Returns a simple DTO for the LWC.
  - refreshWeatherForLocation(Id locationId)  
    - Checks that latitude and longitude are filled.  
    - Calls WeatherApiClient.getCurrentWeather.  
    - Creates a new WeatherInfo__c record and marks it as latest.  
    - Updates Last_Weather_Updated__c and Last_Weather_Status__c on Location__c.

There are helper methods to map API → custom object and to keep only one IsLatest__c per Location.

---

5. LWC: weatherDisplay

- LWC placed on the Location__c record page.
- On load:
  - Calls getLatestWeatherForLocation (cacheable) to show whatever is already stored.
- Button:
  - Refresh / Get Weather Details calls refreshWeatherForLocation.
  - Shows a spinner while loading.
  - Shows a toast for success or error.

What it displays:
- Location name
- Temperature (in the units configured: usually °C with `metric`)
- Weather description
- Humidity
- Wind speed
- Last retrieved time
- Optional: last status stored on the Location record

---
6. How to deploy

Option 1: Using SFDX

1. Create / select a scratch org or sandbox.
2. Set up your `force-app` folder as usual.
3. Deploy:

   bash
   sfdx force:source:deploy -p force-app/main/default
   
   

In Salesforce:

Create the Location__c and WeatherInfo__c objects and fields (if not included as metadata).

Create the Named Credential OpenWeather.

Create Weather_Config__mdt and the Default record with your API key.

Go to a Location__c record → Edit Page → drop weatherDisplay onto the page.

Option 2: Manual

If you don’t use SFDX, you can also:

Create the objects and fields in Setup.

Copy/paste the Apex classes and LWC files into your org via Dev Console / VS Code.

7. How to test

Create a Location__c record:

Name: e.g. London HQ

Latitude__c: 51.5074

Longitude__c: -0.1278

Open the record in Lightning.

Click “Refresh / Get Weather Details”.

You should see the weather data and the WeatherInfo__c record created.

There are also Apex test classes (WeatherApiClientTest, WeatherServiceTest) that use HttpCalloutMock to simulate the API, so tests can run in a normal Salesforce test context.

8. Design choices (very short)

Separation of concerns:

API client vs service layer vs UI.

Config via metadata:

API key and units are in Custom Metadata so I don’t hard-code secrets.

Scalability (optional part):

Batch + schedulable job could refresh many locations in the background if needed.

User experience:

Simple LWC on the record, one button to refresh, clear messages when something is wrong (e.g. missing latitude/longitude).
