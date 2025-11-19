"""
Comprehensive Model Evaluation Script

Generates:
1. Training and Testing Accuracy/Loss Graphs
2. Confusion Matrix with Heatmap
3. Precision, Recall, F1-Score Table and Graphs
4. Classification Report
5. ROC Curves and AUC Scores
6. Per-class Performance Metrics

Run this after training to get complete evaluation metrics.
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import (
    confusion_matrix, classification_report, 
    precision_recall_fscore_support, roc_curve, auc,
    accuracy_score, roc_auc_score
)
from sklearn.preprocessing import label_binarize
import tensorflow as tf
from tensorflow import keras
import json
import os

# Set style for better-looking plots
plt.style.use('seaborn-v0_8-darkgrid')
sns.set_palette("husl")

# Stop types mapping
STOP_TYPES = {
    0: 'Traffic Signal',
    1: 'Toll Gate',
    2: 'Regular Stop',
    3: 'Gas Station',
    4: 'Rest Area'
}

def generate_synthetic_data(n_samples=10000):
    """Generate synthetic training data"""
    data = []
    
    for _ in range(n_samples):
        stop_type = np.random.choice([0, 1, 2, 3, 4])
        
        if stop_type == 0:  # Traffic Signal
            dwell_time = np.random.normal(25, 10)
            speed_before = np.random.normal(35, 15)
            visit_count = np.random.randint(1, 5)
        elif stop_type == 1:  # Toll Gate
            dwell_time = np.random.normal(60, 20)
            speed_before = np.random.normal(70, 20)
            visit_count = np.random.randint(1, 10)
        elif stop_type == 2:  # Regular Stop
            dwell_time = np.random.normal(120, 40)
            speed_before = np.random.normal(30, 10)
            visit_count = np.random.randint(3, 20)
        elif stop_type == 3:  # Gas Station
            dwell_time = np.random.normal(420, 180)
            speed_before = np.random.normal(60, 15)
            visit_count = np.random.randint(1, 8)
        else:  # Rest Area
            dwell_time = np.random.normal(1200, 300)
            speed_before = np.random.normal(70, 15)
            visit_count = np.random.randint(1, 5)
        
        heading = np.random.uniform(0, 360)
        hour = np.random.randint(0, 24)
        day_of_week = np.random.randint(0, 7)
        
        dwell_time = max(10, dwell_time)
        speed_before = max(0, min(120, speed_before))
        
        data.append({
            'dwell_time': dwell_time,
            'speed_before': speed_before,
            'heading': heading,
            'visit_count': visit_count,
            'hour': hour,
            'day_of_week': day_of_week,
            'stop_type': stop_type
        })
    
    return pd.DataFrame(data)

def create_model(input_shape, num_classes):
    """Create neural network model"""
    model = keras.Sequential([
        keras.layers.Input(shape=(input_shape,)),
        keras.layers.Dense(128, activation='relu'),
        keras.layers.Dropout(0.3),
        keras.layers.BatchNormalization(),
        keras.layers.Dense(64, activation='relu'),
        keras.layers.Dropout(0.2),
        keras.layers.BatchNormalization(),
        keras.layers.Dense(32, activation='relu'),
        keras.layers.Dropout(0.2),
        keras.layers.Dense(num_classes, activation='softmax')
    ])
    return model

def plot_training_history(history, save_path='results/training_history.png'):
    """Plot training and validation accuracy/loss"""
    fig, axes = plt.subplots(1, 2, figsize=(15, 5))
    
    # Accuracy plot
    axes[0].plot(history.history['accuracy'], label='Training Accuracy', linewidth=2)
    axes[0].plot(history.history['val_accuracy'], label='Validation Accuracy', linewidth=2)
    axes[0].set_title('Model Accuracy Over Epochs', fontsize=14, fontweight='bold')
    axes[0].set_xlabel('Epoch', fontsize=12)
    axes[0].set_ylabel('Accuracy', fontsize=12)
    axes[0].legend(loc='lower right', fontsize=10)
    axes[0].grid(True, alpha=0.3)
    
    # Loss plot
    axes[1].plot(history.history['loss'], label='Training Loss', linewidth=2)
    axes[1].plot(history.history['val_loss'], label='Validation Loss', linewidth=2)
    axes[1].set_title('Model Loss Over Epochs', fontsize=14, fontweight='bold')
    axes[1].set_xlabel('Epoch', fontsize=12)
    axes[1].set_ylabel('Loss', fontsize=12)
    axes[1].legend(loc='upper right', fontsize=10)
    axes[1].grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(save_path, dpi=300, bbox_inches='tight')
    print(f"✅ Training history plot saved to {save_path}")
    plt.close()

def plot_confusion_matrix(y_true, y_pred, save_path='results/confusion_matrix.png'):
    """Plot confusion matrix heatmap"""
    cm = confusion_matrix(y_true, y_pred)
    
    plt.figure(figsize=(10, 8))
    sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', 
                xticklabels=STOP_TYPES.values(),
                yticklabels=STOP_TYPES.values(),
                cbar_kws={'label': 'Count'},
                linewidths=0.5, linecolor='gray')
    
    plt.title('Confusion Matrix - Stop Classification', fontsize=16, fontweight='bold', pad=20)
    plt.ylabel('True Label', fontsize=12, fontweight='bold')
    plt.xlabel('Predicted Label', fontsize=12, fontweight='bold')
    plt.xticks(rotation=45, ha='right')
    plt.yticks(rotation=0)
    
    # Add accuracy annotation
    accuracy = accuracy_score(y_true, y_pred)
    plt.text(0.5, -0.15, f'Overall Accuracy: {accuracy:.2%}', 
             ha='center', transform=plt.gca().transAxes,
             fontsize=12, bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))
    
    plt.tight_layout()
    plt.savefig(save_path, dpi=300, bbox_inches='tight')
    print(f"✅ Confusion matrix saved to {save_path}")
    plt.close()

def plot_classification_metrics(y_true, y_pred, save_path='results/classification_metrics.png'):
    """Plot precision, recall, F1-score as bar charts"""
    precision, recall, f1, support = precision_recall_fscore_support(y_true, y_pred)
    
    fig, axes = plt.subplots(2, 2, figsize=(16, 12))
    
    classes = list(STOP_TYPES.values())
    x_pos = np.arange(len(classes))
    
    # Precision
    bars1 = axes[0, 0].bar(x_pos, precision, color='skyblue', edgecolor='navy', linewidth=1.5)
    axes[0, 0].set_title('Precision by Class', fontsize=14, fontweight='bold')
    axes[0, 0].set_ylabel('Precision', fontsize=12)
    axes[0, 0].set_xticks(x_pos)
    axes[0, 0].set_xticklabels(classes, rotation=45, ha='right')
    axes[0, 0].set_ylim([0, 1.1])
    axes[0, 0].grid(axis='y', alpha=0.3)
    for i, bar in enumerate(bars1):
        height = bar.get_height()
        axes[0, 0].text(bar.get_x() + bar.get_width()/2., height,
                       f'{precision[i]:.3f}', ha='center', va='bottom', fontweight='bold')
    
    # Recall
    bars2 = axes[0, 1].bar(x_pos, recall, color='lightcoral', edgecolor='darkred', linewidth=1.5)
    axes[0, 1].set_title('Recall by Class', fontsize=14, fontweight='bold')
    axes[0, 1].set_ylabel('Recall', fontsize=12)
    axes[0, 1].set_xticks(x_pos)
    axes[0, 1].set_xticklabels(classes, rotation=45, ha='right')
    axes[0, 1].set_ylim([0, 1.1])
    axes[0, 1].grid(axis='y', alpha=0.3)
    for i, bar in enumerate(bars2):
        height = bar.get_height()
        axes[0, 1].text(bar.get_x() + bar.get_width()/2., height,
                       f'{recall[i]:.3f}', ha='center', va='bottom', fontweight='bold')
    
    # F1-Score
    bars3 = axes[1, 0].bar(x_pos, f1, color='lightgreen', edgecolor='darkgreen', linewidth=1.5)
    axes[1, 0].set_title('F1-Score by Class', fontsize=14, fontweight='bold')
    axes[1, 0].set_ylabel('F1-Score', fontsize=12)
    axes[1, 0].set_xticks(x_pos)
    axes[1, 0].set_xticklabels(classes, rotation=45, ha='right')
    axes[1, 0].set_ylim([0, 1.1])
    axes[1, 0].grid(axis='y', alpha=0.3)
    for i, bar in enumerate(bars3):
        height = bar.get_height()
        axes[1, 0].text(bar.get_x() + bar.get_width()/2., height,
                       f'{f1[i]:.3f}', ha='center', va='bottom', fontweight='bold')
    
    # Combined comparison
    width = 0.25
    x_pos_multi = np.arange(len(classes))
    axes[1, 1].bar(x_pos_multi - width, precision, width, label='Precision', 
                   color='skyblue', edgecolor='navy', linewidth=1.5)
    axes[1, 1].bar(x_pos_multi, recall, width, label='Recall', 
                   color='lightcoral', edgecolor='darkred', linewidth=1.5)
    axes[1, 1].bar(x_pos_multi + width, f1, width, label='F1-Score', 
                   color='lightgreen', edgecolor='darkgreen', linewidth=1.5)
    axes[1, 1].set_title('Combined Metrics Comparison', fontsize=14, fontweight='bold')
    axes[1, 1].set_ylabel('Score', fontsize=12)
    axes[1, 1].set_xticks(x_pos_multi)
    axes[1, 1].set_xticklabels(classes, rotation=45, ha='right')
    axes[1, 1].set_ylim([0, 1.1])
    axes[1, 1].legend(loc='upper right', fontsize=10)
    axes[1, 1].grid(axis='y', alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(save_path, dpi=300, bbox_inches='tight')
    print(f"✅ Classification metrics plot saved to {save_path}")
    plt.close()

def create_metrics_table(y_true, y_pred, save_path='results/metrics_table.png'):
    """Create a detailed metrics table as image"""
    precision, recall, f1, support = precision_recall_fscore_support(y_true, y_pred)
    
    # Calculate accuracy per class
    accuracy_per_class = []
    for i in range(len(STOP_TYPES)):
        mask = y_true == i
        if mask.sum() > 0:
            acc = accuracy_score(y_true[mask], y_pred[mask])
        else:
            acc = 0
        accuracy_per_class.append(acc)
    
    # Create DataFrame
    df = pd.DataFrame({
        'Class': list(STOP_TYPES.values()),
        'Precision': [f'{p:.4f}' for p in precision],
        'Recall': [f'{r:.4f}' for r in recall],
        'F1-Score': [f'{f:.4f}' for f in f1],
        'Accuracy': [f'{a:.4f}' for a in accuracy_per_class],
        'Support': support
    })
    
    # Add average row
    avg_row = pd.DataFrame({
        'Class': ['Weighted Avg'],
        'Precision': [f'{np.average(precision, weights=support):.4f}'],
        'Recall': [f'{np.average(recall, weights=support):.4f}'],
        'F1-Score': [f'{np.average(f1, weights=support):.4f}'],
        'Accuracy': [f'{accuracy_score(y_true, y_pred):.4f}'],
        'Support': [support.sum()]
    })
    df = pd.concat([df, avg_row], ignore_index=True)
    
    # Create figure
    fig, ax = plt.subplots(figsize=(14, 8))
    ax.axis('tight')
    ax.axis('off')
    
    # Create table
    table = ax.table(cellText=df.values, colLabels=df.columns,
                     cellLoc='center', loc='center',
                     colWidths=[0.25, 0.15, 0.15, 0.15, 0.15, 0.15])
    
    table.auto_set_font_size(False)
    table.set_fontsize(11)
    table.scale(1, 2.5)
    
    # Style header
    for i in range(len(df.columns)):
        cell = table[(0, i)]
        cell.set_facecolor('#4CAF50')
        cell.set_text_props(weight='bold', color='white', fontsize=12)
    
    # Style rows
    for i in range(1, len(df) + 1):
        for j in range(len(df.columns)):
            cell = table[(i, j)]
            if i == len(df):  # Last row (average)
                cell.set_facecolor('#FFF9C4')
                cell.set_text_props(weight='bold')
            elif i % 2 == 0:
                cell.set_facecolor('#E8F5E9')
            else:
                cell.set_facecolor('#FFFFFF')
    
    plt.title('Detailed Classification Metrics Table', 
              fontsize=16, fontweight='bold', pad=20)
    
    plt.savefig(save_path, dpi=300, bbox_inches='tight')
    print(f"✅ Metrics table saved to {save_path}")
    plt.close()
    
    return df

def plot_roc_curves(y_true, y_pred_proba, save_path='results/roc_curves.png'):
    """Plot ROC curves for each class"""
    n_classes = len(STOP_TYPES)
    
    # Binarize the output
    y_true_bin = label_binarize(y_true, classes=list(range(n_classes)))
    
    # Compute ROC curve and AUC for each class
    fpr = dict()
    tpr = dict()
    roc_auc = dict()
    
    for i in range(n_classes):
        fpr[i], tpr[i], _ = roc_curve(y_true_bin[:, i], y_pred_proba[:, i])
        roc_auc[i] = auc(fpr[i], tpr[i])
    
    # Plot
    plt.figure(figsize=(12, 8))
    colors = plt.cm.Set3(np.linspace(0, 1, n_classes))
    
    for i, color in enumerate(colors):
        plt.plot(fpr[i], tpr[i], color=color, lw=2.5,
                label=f'{STOP_TYPES[i]} (AUC = {roc_auc[i]:.3f})')
    
    plt.plot([0, 1], [0, 1], 'k--', lw=2, label='Random Classifier')
    plt.xlim([0.0, 1.0])
    plt.ylim([0.0, 1.05])
    plt.xlabel('False Positive Rate', fontsize=12, fontweight='bold')
    plt.ylabel('True Positive Rate', fontsize=12, fontweight='bold')
    plt.title('ROC Curves - Multi-class Classification', fontsize=16, fontweight='bold')
    plt.legend(loc='lower right', fontsize=10)
    plt.grid(alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(save_path, dpi=300, bbox_inches='tight')
    print(f"✅ ROC curves saved to {save_path}")
    plt.close()

def generate_summary_report(history, y_true, y_pred, save_path='results/summary_report.txt'):
    """Generate text summary report"""
    with open(save_path, 'w', encoding='utf-8') as f:
        f.write("="*70 + "\n")
        f.write("TRAVION - STOP CLASSIFICATION MODEL EVALUATION REPORT\n")
        f.write("="*70 + "\n\n")
        
        # Training metrics
        f.write("TRAINING METRICS\n")
        f.write("-"*70 + "\n")
        f.write(f"Final Training Accuracy:   {history.history['accuracy'][-1]:.4f}\n")
        f.write(f"Final Validation Accuracy: {history.history['val_accuracy'][-1]:.4f}\n")
        f.write(f"Final Training Loss:       {history.history['loss'][-1]:.4f}\n")
        f.write(f"Final Validation Loss:     {history.history['val_loss'][-1]:.4f}\n")
        f.write(f"Total Epochs:              {len(history.history['accuracy'])}\n\n")
        
        # Test metrics
        f.write("TEST SET METRICS\n")
        f.write("-"*70 + "\n")
        f.write(f"Test Accuracy: {accuracy_score(y_true, y_pred):.4f}\n\n")
        
        # Classification report
        f.write("DETAILED CLASSIFICATION REPORT\n")
        f.write("-"*70 + "\n")
        report = classification_report(y_true, y_pred, 
                                      target_names=list(STOP_TYPES.values()),
                                      digits=4)
        f.write(report)
        f.write("\n")
        
        # Confusion matrix
        f.write("CONFUSION MATRIX\n")
        f.write("-"*70 + "\n")
        cm = confusion_matrix(y_true, y_pred)
        f.write("Predicted →\n")
        f.write("True ↓\n\n")
        
        # Header
        f.write("             ")
        for class_name in STOP_TYPES.values():
            f.write(f"{class_name[:10]:>12}")
        f.write("\n")
        
        # Rows
        for i, class_name in enumerate(STOP_TYPES.values()):
            f.write(f"{class_name[:12]:<12} ")
            for j in range(len(STOP_TYPES)):
                f.write(f"{cm[i][j]:>12}")
            f.write("\n")
        
        f.write("\n" + "="*70 + "\n")
        f.write("Report generated successfully!\n")
        f.write("="*70 + "\n")
    
    print(f"✅ Summary report saved to {save_path}")

def main():
    """Main evaluation pipeline"""
    print("="*70)
    print("TRAVION - MODEL EVALUATION & METRICS GENERATION")
    print("="*70)
    
    # Create results directory
    os.makedirs('results', exist_ok=True)
    
    # Generate data
    print("\n📊 Generating synthetic data...")
    df = generate_synthetic_data(n_samples=10000)
    
    # Prepare features
    feature_columns = ['dwell_time', 'speed_before', 'heading', 'visit_count', 'hour', 'day_of_week']
    X = df[feature_columns].values
    y = df['stop_type'].values
    
    # Split data
    print("📊 Splitting data...")
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    X_train, X_val, y_train, y_val = train_test_split(
        X_train, y_train, test_size=0.2, random_state=42, stratify=y_train
    )
    
    # Normalize
    print("📊 Normalizing features...")
    scaler = StandardScaler()
    X_train = scaler.fit_transform(X_train)
    X_val = scaler.transform(X_val)
    X_test = scaler.transform(X_test)
    
    # Create and train model
    print("🤖 Training model...")
    model = create_model(X_train.shape[1], len(STOP_TYPES))
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=0.001),
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    
    early_stopping = keras.callbacks.EarlyStopping(
        monitor='val_loss', patience=10, restore_best_weights=True
    )
    reduce_lr = keras.callbacks.ReduceLROnPlateau(
        monitor='val_loss', factor=0.5, patience=5, min_lr=0.00001
    )
    
    history = model.fit(
        X_train, y_train,
        validation_data=(X_val, y_val),
        epochs=100,
        batch_size=32,
        callbacks=[early_stopping, reduce_lr],
        verbose=1
    )
    
    # Predictions
    print("\n🔮 Generating predictions...")
    y_pred_proba = model.predict(X_test)
    y_pred = np.argmax(y_pred_proba, axis=1)
    
    # Generate all visualizations
    print("\n📈 Generating visualizations...")
    print("-"*70)
    
    plot_training_history(history)
    plot_confusion_matrix(y_test, y_pred)
    plot_classification_metrics(y_test, y_pred)
    metrics_df = create_metrics_table(y_test, y_pred)
    plot_roc_curves(y_test, y_pred_proba)
    generate_summary_report(history, y_test, y_pred)
    
    # Print metrics table to console
    print("\n📊 METRICS TABLE:")
    print("-"*70)
    print(metrics_df.to_string(index=False))
    print("-"*70)
    
    # Final summary
    print("\n✅ EVALUATION COMPLETE!")
    print("="*70)
    print("\n📁 All results saved to 'results/' directory:")
    print("   • training_history.png     - Accuracy & Loss curves")
    print("   • confusion_matrix.png     - Confusion matrix heatmap")
    print("   • classification_metrics.png - Precision/Recall/F1 graphs")
    print("   • metrics_table.png        - Detailed metrics table")
    print("   • roc_curves.png          - ROC curves for all classes")
    print("   • summary_report.txt      - Complete text report")
    print("="*70)
    
    # Test set accuracy
    test_accuracy = accuracy_score(y_test, y_pred)
    print(f"\n🎯 Final Test Accuracy: {test_accuracy:.2%}")
    print("="*70)

if __name__ == "__main__":
    main()
