"""
Comparative Analysis: Grid-Connected vs Islanded Mode
Compares FDIA detection performance between operating modes
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import os


def load_results(mode='grid'):
    """Load MSE results and calculate statistics"""
    if mode == 'grid':
        mse_file = 'mseList.csv'
        label_file = 'VectorDataset/labelData.csv'
    else:  # islanded
        mse_file = 'mseList_islanded.csv'
        label_file = 'VectorDataset_Islanded/labelData.csv'
    
    if not os.path.exists(mse_file):
        print(f"Warning: {mse_file} not found. Run Evaluation{'_Islanded' if mode=='islanded' else ''}.py first.")
        return None
    
    mse_df = pd.read_csv(mse_file, header=None, names=['mse'])
    labels_df = pd.read_csv(label_file, header=None, names=['label'])
    
    # Align lengths (evaluation starts from index 5)
    labels = labels_df['label'].values[5:5+len(mse_df)]
    mse_values = mse_df['mse'].values
    
    return {
        'mse': mse_values,
        'labels': labels,
        'mode': mode
    }


def calculate_metrics(results, threshold=20):
    """Calculate detection metrics"""
    mse = results['mse']
    labels = results['labels']
    
    # Predictions based on threshold
    predictions = (mse > threshold).astype(int)
    
    # Confusion matrix
    true_positives = np.sum((predictions == 1) & (labels == 1))
    true_negatives = np.sum((predictions == 0) & (labels == 0))
    false_positives = np.sum((predictions == 1) & (labels == 0))
    false_negatives = np.sum((predictions == 0) & (labels == 1))
    
    # Metrics
    accuracy = (true_positives + true_negatives) / len(labels)
    precision = true_positives / (true_positives + false_positives) if (true_positives + false_positives) > 0 else 0
    recall = true_positives / (true_positives + false_negatives) if (true_positives + false_negatives) > 0 else 0
    f1_score = 2 * (precision * recall) / (precision + recall) if (precision + recall) > 0 else 0
    
    return {
        'accuracy': accuracy * 100,
        'precision': precision * 100,
        'recall': recall * 100,
        'f1_score': f1_score * 100,
        'true_positives': true_positives,
        'true_negatives': true_negatives,
        'false_positives': false_positives,
        'false_negatives': false_negatives,
        'mean_mse': np.mean(mse),
        'std_mse': np.std(mse),
        'max_mse': np.max(mse),
        'min_mse': np.min(mse)
    }


def print_comparison(grid_metrics, islanded_metrics):
    """Print side-by-side comparison"""
    print("\n" + "="*80)
    print("COMPARATIVE ANALYSIS: GRID-CONNECTED vs ISLANDED MODE")
    print("="*80)
    print(f"{'Metric':<25} {'Grid-Connected':<25} {'Islanded':<25}")
    print("-"*80)
    
    metrics_to_compare = [
        ('Accuracy (%)', 'accuracy'),
        ('Precision (%)', 'precision'),
        ('Recall (%)', 'recall'),
        ('F1 Score (%)', 'f1_score'),
        ('True Positives', 'true_positives'),
        ('True Negatives', 'true_negatives'),
        ('False Positives', 'false_positives'),
        ('False Negatives', 'false_negatives'),
        ('Mean MSE', 'mean_mse'),
        ('Std MSE', 'std_mse'),
        ('Max MSE', 'max_mse'),
        ('Min MSE', 'min_mse')
    ]
    
    for label, key in metrics_to_compare:
        grid_val = grid_metrics[key]
        islanded_val = islanded_metrics[key] if islanded_metrics else 'N/A'
        
        if isinstance(grid_val, float):
            grid_str = f"{grid_val:.2f}"
            islanded_str = f"{islanded_val:.2f}" if islanded_val != 'N/A' else 'N/A'
        else:
            grid_str = str(grid_val)
            islanded_str = str(islanded_val) if islanded_val != 'N/A' else 'N/A'
        
        print(f"{label:<25} {grid_str:<25} {islanded_str:<25}")
    
    print("="*80)


def plot_comparison(grid_results, islanded_results):
    """Create visualization comparing both modes"""
    fig, axes = plt.subplots(2, 2, figsize=(15, 10))
    fig.suptitle('Grid-Connected vs Islanded Mode Comparison', fontsize=16, fontweight='bold')
    
    # Plot 1: MSE Distribution
    ax1 = axes[0, 0]
    ax1.hist(grid_results['mse'], bins=50, alpha=0.6, label='Grid-Connected', color='blue')
    if islanded_results:
        ax1.hist(islanded_results['mse'], bins=50, alpha=0.6, label='Islanded', color='orange')
    ax1.axvline(x=20, color='red', linestyle='--', label='Threshold (MSE=20)')
    ax1.set_xlabel('MSE Value')
    ax1.set_ylabel('Frequency')
    ax1.set_title('MSE Distribution')
    ax1.legend()
    ax1.set_yscale('log')
    
    # Plot 2: MSE over Time
    ax2 = axes[0, 1]
    ax2.plot(grid_results['mse'][:1000], alpha=0.7, label='Grid-Connected', linewidth=0.8)
    if islanded_results:
        ax2.plot(islanded_results['mse'][:1000], alpha=0.7, label='Islanded', linewidth=0.8)
    ax2.axhline(y=20, color='red', linestyle='--', label='Threshold')
    ax2.set_xlabel('Sample Index')
    ax2.set_ylabel('MSE Value')
    ax2.set_title('MSE Time Series (First 1000 samples)')
    ax2.legend()
    
    # Plot 3: Attack Detection Accuracy
    ax3 = axes[1, 0]
    grid_metrics = calculate_metrics(grid_results)
    islanded_metrics = calculate_metrics(islanded_results) if islanded_results else None
    
    metrics = ['Accuracy', 'Precision', 'Recall', 'F1 Score']
    grid_values = [grid_metrics['accuracy'], grid_metrics['precision'], 
                   grid_metrics['recall'], grid_metrics['f1_score']]
    
    x = np.arange(len(metrics))
    width = 0.35
    
    ax3.bar(x - width/2, grid_values, width, label='Grid-Connected', color='blue', alpha=0.7)
    if islanded_metrics:
        islanded_values = [islanded_metrics['accuracy'], islanded_metrics['precision'],
                          islanded_metrics['recall'], islanded_metrics['f1_score']]
        ax3.bar(x + width/2, islanded_values, width, label='Islanded', color='orange', alpha=0.7)
    
    ax3.set_ylabel('Percentage (%)')
    ax3.set_title('Detection Performance Metrics')
    ax3.set_xticks(x)
    ax3.set_xticklabels(metrics, rotation=15)
    ax3.legend()
    ax3.set_ylim([0, 105])
    
    # Plot 4: Confusion Matrix Comparison
    ax4 = axes[1, 1]
    confusion_data = [
        ['True Pos', grid_metrics['true_positives'], 
         islanded_metrics['true_positives'] if islanded_metrics else 0],
        ['True Neg', grid_metrics['true_negatives'],
         islanded_metrics['true_negatives'] if islanded_metrics else 0],
        ['False Pos', grid_metrics['false_positives'],
         islanded_metrics['false_positives'] if islanded_metrics else 0],
        ['False Neg', grid_metrics['false_negatives'],
         islanded_metrics['false_negatives'] if islanded_metrics else 0]
    ]
    
    categories = [row[0] for row in confusion_data]
    grid_counts = [row[1] for row in confusion_data]
    islanded_counts = [row[2] for row in confusion_data]
    
    x = np.arange(len(categories))
    ax4.bar(x - width/2, grid_counts, width, label='Grid-Connected', color='blue', alpha=0.7)
    if islanded_metrics:
        ax4.bar(x + width/2, islanded_counts, width, label='Islanded', color='orange', alpha=0.7)
    
    ax4.set_ylabel('Count')
    ax4.set_title('Confusion Matrix Comparison')
    ax4.set_xticks(x)
    ax4.set_xticklabels(categories)
    ax4.legend()
    
    plt.tight_layout()
    plt.savefig('comparison_analysis.png', dpi=300, bbox_inches='tight')
    print("\nVisualization saved to: comparison_analysis.png")
    plt.show()


def main():
    """Main comparison function"""
    print("\n" + "="*80)
    print("LOADING RESULTS...")
    print("="*80)
    
    # Load results
    grid_results = load_results('grid')
    islanded_results = load_results('islanded')
    
    if grid_results is None:
        print("Error: Grid-connected results not found. Run Evaluation.py first.")
        return
    
    # Calculate metrics
    grid_metrics = calculate_metrics(grid_results)
    islanded_metrics = calculate_metrics(islanded_results) if islanded_results else None
    
    # Print comparison
    print_comparison(grid_metrics, islanded_metrics)
    
    # Plot comparison
    if islanded_results:
        plot_comparison(grid_results, islanded_results)
    else:
        print("\nNote: Islanded mode results not available. Run Evaluation_Islanded.py to enable full comparison.")
        print("Showing grid-connected results only...")
        
        # Show grid-only plot
        plt.figure(figsize=(12, 5))
        plt.subplot(1, 2, 1)
        plt.hist(grid_results['mse'], bins=50, alpha=0.7, color='blue')
        plt.axvline(x=20, color='red', linestyle='--', label='Threshold')
        plt.xlabel('MSE Value')
        plt.ylabel('Frequency')
        plt.title('Grid-Connected MSE Distribution')
        plt.legend()
        plt.yscale('log')
        
        plt.subplot(1, 2, 2)
        metrics = ['Accuracy', 'Precision', 'Recall', 'F1 Score']
        values = [grid_metrics['accuracy'], grid_metrics['precision'],
                 grid_metrics['recall'], grid_metrics['f1_score']]
        plt.bar(metrics, values, color='blue', alpha=0.7)
        plt.ylabel('Percentage (%)')
        plt.title('Grid-Connected Detection Performance')
        plt.xticks(rotation=15)
        plt.ylim([0, 105])
        
        plt.tight_layout()
        plt.savefig('grid_analysis.png', dpi=300, bbox_inches='tight')
        print("Grid-connected visualization saved to: grid_analysis.png")
        plt.show()


if __name__ == "__main__":
    main()
