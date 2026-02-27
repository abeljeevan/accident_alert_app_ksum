"""
Export Random Forest model to JSON format for Flutter/Dart integration
This exports the complete tree structure for native Dart implementation
"""

import joblib
import json
import numpy as np
from pathlib import Path
from sklearn.ensemble import RandomForestClassifier
import sys

def export_tree_structure(tree, feature_names):
    """Extract tree structure from sklearn tree"""
    tree_data = {
        'n_nodes': int(tree.node_count),
        'nodes': [],
        'values': []
    }
    
    # Extract node information
    for i in range(tree.node_count):
        node_info = {
            'feature': int(tree.feature[i]) if tree.feature[i] != -2 else -1,
            'threshold': float(tree.threshold[i]) if tree.threshold[i] != -2 else 0.0,
            'left_child': int(tree.children_left[i]),
            'right_child': int(tree.children_right[i]),
            'impurity': float(tree.impurity[i]),
            'n_samples': int(tree.n_node_samples[i]),
            'weighted_n_samples': float(tree.weighted_n_node_samples[i]),
        }
        
        # Leaf node values (class probabilities)
        if tree.children_left[i] == -1:  # Leaf node
            value = tree.value[i][0]
            node_info['value'] = [float(v) for v in value]
            # Predicted class (0: FAKE, 1: REAL)
            node_info['predicted_class'] = int(np.argmax(value))
        
        tree_data['nodes'].append(node_info)
    
    return tree_data

def main():
    print("Loading trained Random Forest model...")
    
    # Load the trained model
    model_path = Path(__file__).parent / 'models' / 'accident_detector_rf.pkl'
    rf_model = joblib.load(model_path)
    
    # Load metadata to get feature names
    metadata_path = Path(__file__).parent / 'models' / 'model_metadata.json'
    with open(metadata_path, 'r') as f:
        metadata = json.load(f)
    
    feature_names = metadata['features']
    class_names = ['FAKE', 'REAL']  # Binary classification
    
    print(f"Model loaded: {len(rf_model.estimators_)} trees")
    print(f"Features: {len(feature_names)}")
    print(f"Classes: {class_names}")
    
    # Export model structure
    export_data = {
        'model_type': 'RandomForestClassifier',
        'n_estimators': len(rf_model.estimators_),
        'n_features': len(feature_names),
        'n_classes': len(class_names),
        'feature_names': feature_names,
        'class_names': class_names,
        'max_depth': int(rf_model.max_depth) if rf_model.max_depth else None,
        'min_samples_split': int(rf_model.min_samples_split),
        'min_samples_leaf': int(rf_model.min_samples_leaf),
        'trees': []
    }
    
    # Export each tree structure
    print("\nExporting tree structures...")
    for idx, estimator in enumerate(rf_model.estimators_):
        if idx % 20 == 0:
            print(f"  Exporting tree {idx + 1}/{len(rf_model.estimators_)}...")
        
        tree = estimator.tree_
        tree_structure = export_tree_structure(tree, feature_names)
        export_data['trees'].append(tree_structure)
    
    # Save to JSON file
    output_path = Path(__file__).parent / 'models' / 'accident_detector_rf.json'
    print(f"\nSaving model to {output_path}...")
    
    with open(output_path, 'w') as f:
        json.dump(export_data, f, indent=2)
    
    # Get file size
    file_size_mb = output_path.stat().st_size / (1024 * 1024)
    print(f"✅ Model exported successfully!")
    print(f"   File size: {file_size_mb:.2f} MB")
    print(f"   Trees: {len(export_data['trees'])}")
    print(f"   Total nodes: {sum(t['n_nodes'] for t in export_data['trees'])}")
    
    # Create a lightweight version (summary for quick loading)
    summary = {
        'model_type': export_data['model_type'],
        'n_estimators': export_data['n_estimators'],
        'n_features': export_data['n_features'],
        'n_classes': export_data['n_classes'],
        'feature_names': export_data['feature_names'],
        'class_names': export_data['class_names'],
        'model_file': 'accident_detector_rf.json'
    }
    
    summary_path = Path(__file__).parent / 'models' / 'model_summary.json'
    with open(summary_path, 'w') as f:
        json.dump(summary, f, indent=2)
    
    print(f"✅ Summary saved to {summary_path}")
    
    # Also copy to Flutter assets
    assets_path = Path(__file__).parent.parent / 'assets' / 'models'
    assets_path.mkdir(parents=True, exist_ok=True)
    
    import shutil
    shutil.copy(output_path, assets_path / 'accident_detector_rf.json')
    shutil.copy(summary_path, assets_path / 'model_summary.json')
    
    print(f"✅ Model copied to Flutter assets: {assets_path}")

if __name__ == '__main__':
    main()
