# fyp

A Flutter application for fruit analysis, nutrition insights, and personalized food suggestions.

## Overview

**fyp** is a mobile app designed to help users analyze fruit freshness, distinguish between artificial and natural fruits, find nutritional information, and receive personalized food suggestions based on their body type. The app leverages machine learning models and LLM-powered endpoints via FastAPI.

## Features

### 1. Fruit Freshness Level Classification

- **Functionality:** Classifies the freshness level of fruits using an image.
- **How to Use:**
    1. On the main page, tap the "Fruit Freshness" icon.
    2. Capture or select an image containing fruits.
    3. Optionally, use the fruit extraction feature to select a specific fruit from a group (powered by Flutter Vision).
    4. The app sends the selected fruit image to the backend (`/predict` endpoint).
    5. View the freshness classification result.

### 2. Artificial vs. Natural Fruit Detection

- **Functionality:** Determines if a fruit is artificial or natural.
- **How to Use:**
    1. Tap the "Artificial/Natural" icon.
    2. Capture or select a fruit image.
    3. The app analyzes the image using a FastAPI model.
    4. View the result indicating whether the fruit is artificial or natural.

### 3. Nutrition Finder

- **Functionality:** Provides nutritional information for various foods and ingredients.
- **How to Use:**
    1. Tap the "Nutrition Finder" icon.
    2. Enter or select a food item or a list of ingredients.
    3. The app queries the FastAPI endpoint powered by an LLM.
    4. View detailed nutritional breakdowns for each ingredient and the overall food item, including calories and nutrients.

### 4. Personalized Food Suggestions

- **Functionality:** Suggests suitable foods based on user body type.
- **How to Use:**
    1. Tap the "Suggestions" icon.
    2. Enter your body type and preferences.
    3. The app communicates with the FastAPI LLM endpoint.
    4. Receive personalized food recommendations tailored to your needs.

## Getting Started

1. **Clone the repository:**
     ```bash
     git clone <repository-url>
     cd fyp
     ```

2. **Install dependencies:**
     ```bash
     flutter pub get
     ```

3. **Run the app:**
     ```bash
     flutter run
     ```

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Flutter Codelabs](https://docs.flutter.dev/get-started/codelab)
- [Flutter Cookbook](https://docs.flutter.dev/cookbook)

## Contributing

Contributions are welcome! Please open issues or submit pull requests for improvements.

## License

This project is licensed under the MIT License.

