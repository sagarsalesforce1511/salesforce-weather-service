import { LightningElement, api, wire, track } from 'lwc';
import getLatestWeatherForLocation from '@salesforce/apex/WeatherService.getLatestWeatherForLocation';
import refreshWeatherForLocation from '@salesforce/apex/WeatherService.refreshWeatherForLocation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class WeatherDisplay extends LightningElement {
    @api recordId;

    @track weather;
    @track loading = false;
    @track error;

    // Load latest saved weather (no callout)
    @wire(getLatestWeatherForLocation, { locationId: '$recordId' })
    wiredWeather({ data, error }) {
        if (data) {
            this.weather = data;
            this.error = undefined;
        } else if (error) {
            this.error = error.body ? error.body.message : error.message;
            this.weather = undefined;
        }
    }

    get hasData() {
        return this.weather && this.weather.temperature !== null && this.weather.temperature !== undefined;
    }

    get hasError() {
        return !!this.error;
    }

    // Refresh button → callout to OpenWeather
    handleRefresh() {
        this.loading = true;
        refreshWeatherForLocation({ locationId: this.recordId })
            .then(result => {
                this.weather = result;
                this.error = undefined;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Weather updated',
                        message: 'Latest weather data fetched',
                        variant: 'success'
                    })
                );
            })
            .catch(err => {
                this.error = err.body ? err.body.message : err.message;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Weather update failed',
                        message: this.error,
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                this.loading = false;
            });
    }

    // Simple getters for template
    get temperature() {
        return this.hasData ? this.weather.temperature : null;
    }

    get description() {
        return this.hasData ? this.weather.description : null;
    }

    get humidity() {
        return this.hasData ? this.weather.humidity : null;
    }

    get windSpeed() {
        return this.hasData ? this.weather.windSpeed : null;
    }

    get lastUpdated() {
        return this.weather && this.weather.retrievedAt ? this.weather.retrievedAt : null;
    }

    // Show empty state when no data and no error
    get showEmptyState() {
        return !this.hasData && !this.hasError;
    }
}
