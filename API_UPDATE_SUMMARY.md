# Flutter App API Integration Updates

This document summarizes the changes made to integrate with the new FastAPI endpoints.

## API Endpoints Updated

### 1. Freshness Detection (`/predict`)
- **URL**: `https://fyp-fast-api-backend.onrender.com/predict`
- **Method**: POST (multipart/form-data)
- **Input**: Image file
- **Output**: 
  - Image with bounding boxes (response body)
  - Ripeness data in response header (`ripeness`)

### 2. Natural vs Artificial (`/natural-artificial`)
- **URL**: `https://fyp-fast-api-backend.onrender.com/natural-artificial`
- **Method**: POST (multipart/form-data)
- **Input**: Image file
- **Output**: 
  - Image with bounding boxes (response body)
  - Freshness data in response header (`freshness`)

### 3. Nutrition Analysis (`/nutrition-analysis`)
- **URL**: `https://fyp-fast-api-backend.onrender.com/nutrition-analysis`
- **Method**: POST (multipart/form-data)
- **Input**: Image file
- **Output**: 
  - Image with bounding boxes (response body)
  - Nutrition data in response header (`nutrition`)

### 4. Food Suggestions (`/food-suggestions`)
- **URL**: `https://fyp-fast-api-backend.onrender.com/food-suggestions`
- **Method**: POST (multipart/form-data)
- **Input**: Form fields (age, gender, height, weight, activity_level, goal, allergies, health_conditions)
- **Output**: JSON array with structured diet plan

## Changes Made

### Main Page (HomeView)
- Updated to handle response headers for ripeness data
- Now saves processed images with bounding boxes
- Improved result parsing for multiple detections

### Freshness Classification Page
- Updated API integration to handle new response format
- Added auto-analysis when image is selected
- Displays processed image with bounding boxes
- Improved result color coding

### Natural vs Artificial Page
- Updated to use new API endpoint
- Added auto-analysis when image is selected
- Displays processed image with bounding boxes
- Parses freshness data from response headers

### Nutrition Finder Page
- **Removed**: Text input for manual ingredients (API only accepts images now)
- Updated to use new API endpoint
- Added auto-analysis when image is selected
- Displays processed image with bounding boxes
- Parses nutrition data from response headers
- Updated UI to focus on image-based analysis

### Food Suggestions Page
- Changed from JSON to form data request format
- Updated response parsing to handle array format
- Enhanced UI to display structured meal plan:
  - Breakfast with calories and examples
  - Lunch with calories and examples
  - Dinner with calories and examples
  - Snacks with calories and examples
  - Foods to avoid section

## Key Features Added

1. **Automatic Analysis**: All image-based features now automatically analyze images when selected
2. **Bounding Box Display**: All detection features now show processed images with bounding boxes
3. **Enhanced Result Display**: Better formatting and color coding for results
4. **Improved Error Handling**: Better parsing of response headers and error messages
5. **Structured Diet Plans**: Food suggestions now show detailed meal plans with calorie breakdowns

## Technical Improvements

- Better header parsing for API responses
- Automatic saving of processed images to local storage
- Improved error handling and user feedback
- More robust JSON parsing for complex response formats
- Auto-image analysis for better user experience

## Usage Instructions

1. **Freshness Detection**: Select an image → App automatically analyzes → Shows result with bounding boxes
2. **Natural vs Artificial**: Select an image → App automatically analyzes → Shows detection results
3. **Nutrition Analysis**: Select an image → App automatically analyzes → Shows nutrition information for detected foods
4. **Food Suggestions**: Fill in personal information → Generate suggestions → View detailed meal plan

All features now work seamlessly with the new API endpoints and provide enhanced visual feedback with bounding box detection.
