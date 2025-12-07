"""
Training script for ISLANDED mode data
Trains LSTM model on untampered islanded microgrid measurements
"""

import pandas as pd
from WndowGenerator import WindowGenerator as WG
import tensorflow as tf
import tensorflow.keras as keras
import os

# Pandas Display Options
pd.set_option('display.min_rows', 60)
pd.set_option('display.max_columns', None)
pd.set_option('display.width', 1000)


def compileAndFit(inputModel, inputWindow, patience=2):
    """
    Compile and train the LSTM model
    
    Args:
        inputModel: Keras model to train
        inputWindow: WindowGenerator object with train/val/test data
        patience: Early stopping patience (epochs)
    
    Returns:
        Trained model
    """
    early_stopping = tf.keras.callbacks.EarlyStopping(monitor='val_loss',
                                                      patience=patience,
                                                      mode='min')

    inputModel.compile(loss=tf.losses.MeanSquaredError(),
                       optimizer=tf.optimizers.Adam(learning_rate=0.01),
                       metrics=[tf.metrics.MeanAbsoluteError()])

    inputModel.fit(inputWindow.train, epochs=20,
                   validation_data=inputWindow.val,
                   callbacks=[early_stopping])

    inputModel.save('Model/model_islanded.h5')

    return inputModel


columnNames = []
for i in range(0, 64):  # Islanded mode has 64 measurements (33 buses + 31 branches)
    columnNames.append(str(i))

# untamperedData is to be loaded for training
filePath = 'VectorDataset_Islanded/untamperedVectorData.csv'
df = pd.read_csv(filePath, header=None, names=columnNames)

# Split the data
trainSplit = int(len(df) * 0.7)
valSplit = int(len(df) * 0.9)

trainDf = df[0:trainSplit]
valDf = df[trainSplit:valSplit]
testDf = df[valSplit:]
denormalizedTest = testDf.copy(deep=True)

numFeatures = df.shape[1]

# Create windows
window = WG(input_width=3, label_width=1, shift=1, train_df=trainDf, val_df=valDf, test_df=testDf,
            label_columns=None)

model = keras.models.Sequential()
model.add(keras.layers.LSTM(64, activation="tanh", return_sequences=True))
model.add(keras.layers.Dense(units=64, activation='linear'))
model.add(keras.layers.LSTM(64, activation="tanh", return_sequences=True))
model.add(keras.layers.Dense(units=64, activation='linear'))
model.add(keras.layers.LSTM(64, activation="tanh", return_sequences=True))
model.add(keras.layers.Dense(units=64, activation='linear'))
model.add(keras.layers.Dense(64))  # 64 outputs for islanded mode

# Check for a model and load it if found
modelFolder = 'Model'
modelPath = modelFolder + r'/model_islanded.h5'
if os.path.exists(modelPath):
    model = tf.keras.models.load_model(modelPath)
    print("Loaded last saved ISLANDED model")
else:
    print("No saved ISLANDED model found. Starting anew")

print("\n" + "="*50)
print("TRAINING ISLANDED MODE MODEL")
print("="*50)
model = compileAndFit(model, window)
print("\n" + "="*50)
print("ISLANDED MODE TRAINING COMPLETE")
print("Model saved to:", modelPath)
print("="*50)
