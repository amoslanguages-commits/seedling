import csv
import os

input_file = r'C:\Users\amosl\Desktop\soma app\vocabulary.csv'
output_file = r'C:\Users\amosl\Desktop\soma app\vocabulary_clean.csv'

header = [
    'vocabulary_id', 'concept_id', 'lang_code', 'word', 'article', 'gender',
    'pronunciation', 'part_of_speech', 'concept_type', 'domain', 'sub_domain',
    'micro_category', 'definition', 'frequency', 'image_id', 'example_sentence',
    'example_sentence_pronunciation'
]

def clean_csv():
    errors = []
    seen_ids = set()
    cleaned_rows = []

    if not os.path.exists(input_file):
        print(f"File not found: {input_file}")
        return

    with open(input_file, mode='r', encoding='utf-8') as f:
        # Read lines first to handle cases where there are no quotes but commas in data
        for i, line in enumerate(f):
            line = line.strip()
            if not line:
                continue
            
            # Simple comma split (assuming the input has no quotes around fields with commas)
            # This is risky if any field *legitimately* contains a comma without being quoted.
            row = line.split(',')
            
            # Trim whitespace from each field
            row = [cell.strip() for cell in row]
            
            # 1. Check Row Length
            if len(row) != 17:
                # If it's close, maybe we can pad or it's a split error
                if len(row) < 17:
                    row += [''] * (17 - len(row))
                    errors.append(f"Line {i+1}: Padded from {len(row)} to 17 columns.")
                else:
                    # Truncate and alert
                    original_len = len(row)
                    row = row[:17]
                    errors.append(f"Line {i+1}: Truncated from {original_len} to 17 columns.")

            # 2. Check for Duplicate IDs (assuming vocabulary_id is the first column)
            vid = row[0]
            if vid in seen_ids:
                errors.append(f"Line {i+1}: Duplicate vocabulary_id '{vid}'.")
            else:
                seen_ids.add(vid)

            # 3. Basic Validation: IDs should be numeric
            if not vid.isdigit():
                errors.append(f"Line {i+1}: vocabulary_id '{vid}' is not numeric.")

            cleaned_rows.append(row)

    # Write out the cleaned file with correct header and quoting
    with open(output_file, mode='w', encoding='utf-8', newline='') as f:
        writer = csv.writer(f, quoting=csv.QUOTE_MINIMAL)
        writer.writerow(header)
        writer.writerows(cleaned_rows)

    print(f"Cleaned file written to: {output_file}")
    if errors:
        print("\nErrors/Fixes Found:")
        for err in errors[:20]: # Show first 20
            print(f" - {err}")
        if len(errors) > 20:
            print(f" ... and {len(errors) - 20} more.")
    else:
        print("\nNo errors found!")

if __name__ == "__main__":
    clean_csv()
