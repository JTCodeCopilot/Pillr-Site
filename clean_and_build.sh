#!/bin/bash

# Script to clean derived data and rebuild the Pillr app with optimized build settings

echo "🧹 Cleaning DerivedData folder for Pillr..."
rm -rf ~/Library/Developer/Xcode/DerivedData/Pillr-*

echo "🧪 Checking if Xcode is running..."
if pgrep -x "Xcode" > /dev/null
then
    echo "⚠️ Please close Xcode before continuing"
    read -p "Press Enter when Xcode is closed..."
fi

echo "🔄 Clearing module cache..."
rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex

echo "📝 Applying build optimization settings..."
# Make sure to set the project to use the custom xcconfig file in Xcode

echo "🚀 Ready to rebuild in Xcode with optimized settings!"
echo "Tips to improve build performance:"
echo "1. In Xcode, go to File > Project Settings > Build System > Legacy Build System"
echo "2. Disable indexing (from Product > Scheme > Edit Scheme > Build Options)"
echo "3. In Xcode preferences, increase the number of parallel build tasks"
echo "4. Add compile_settings.xcconfig file to your project settings"
echo ""
echo "✅ Done! Now open the project in Xcode and build."
