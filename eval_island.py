"""
Evaluation script for ISLANDED mode
Tests FDIA detection on islanded microgrid data
"""

import pandas as pd
from WndowGenerator import WindowGenerator as WG
import tensorflow as tf
import numpy as np


def mse(received, pred):
    """Calculate Mean Squared Error"""
    received, pred = np.array(received), np.array(pred)
    return np.square(np.subtract(received, pred)).mean()


def mae(pred, received):
    """Calculate Mean Absolute Error"""
    return (abs(pred - received)) / pred


def mase(pred, received):
    """Calculate Mean Absolute Squared Error"""
    return ((abs(pred - received)) / pred)**2


# Pandas Display Options
pd.set_option('display.min_rows', 60)
pd.set_option('display.max_columns', None)
pd.set_option('display.width', 1000)

columnNames = []
for i in range(0, 64):  # Islanded mode has 64 measurements
    columnNames.append(str(i))

# tamperedData is to be loaded for predicting
filePath = 'VectorDataset_Islanded/tamperedVectorData.csv'
tamperedDf = pd.read_csv(filePath, header=None, names=columnNames)
tamperedList = tamperedDf.values
tamperedList = tamperedList[5:]

# labelData is to be loaded for evaluation
filePath = 'VectorDataset_Islanded/labelData.csv'
labelsDf = pd.read_csv(filePath, header=None, names=['label'])
labelsList = labelsDf.values
labelsList = labelsList[5:]

numFeatures = tamperedDf.shape[1]

# Create windows
window = WG(input_width=5, label_width=1, shift=1, train_df=tamperedDf, val_df=tamperedDf, test_df=tamperedDf,
            label_columns=None)  # Only the test_df will be used

# Load the model
modelFolder = r'Model'
model = tf.keras.models.load_model(modelFolder + r'/model_islanded.h5')

print("\n" + "="*60)
print("EVALUATING ISLANDED MODE DETECTION")
print("="*60)

# Predictions
predictions = model.predict(window.test)
extractedPredictions = []
for i in range(len(predictions)):
    extractedPredictions.append(predictions[i][4])


numOfSuccesses = 0
mseList = []
for i in range(len(extractedPredictions)):
    currentMse = mse(tamperedList[i], extractedPredictions[i])
    mseList.append(currentMse)

    if currentMse > 20:
        detected = True
    else:
        detected = False

    success = labelsList[i] == detected
    if success:
        numOfSuccesses += 1

    if ~success:
        print("!!!!!!!!!! EVALUATION FAILED !!!!!!!!!!", labelsList[i], currentMse)
    else:
        print("Evaluation successful. ", "FDIA Detected? ", detected, "   Calculated MSE: ", currentMse)

successRate = (numOfSuccesses/len(extractedPredictions)) * 100

mseDf = pd.DataFrame(mseList)
mseDf.to_csv(r"mseList_islanded.csv", index=False, header=False)

print("="*60)
print("ISLANDED MODE RESULTS")
print("="*60)
print("Success Rate: ", successRate, "%")
print("Total Samples:", len(extractedPredictions))
print("Correct Detections:", numOfSuccesses)
print("Failed Detections:", len(extractedPredictions) - numOfSuccesses)
print("MSE values saved to: mseList_islanded.csv")
print("="*60)
