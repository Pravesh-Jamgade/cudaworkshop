#!/bin/bash

# ---------------------------------------------
# Usage:
#   bash test.sh RollNumber.out
# ---------------------------------------------

STUDENT_PROGRAM="$1"

if [ -z "$STUDENT_PROGRAM" ]; then
    echo "Usage: bash test.sh RollNumber.out"
    exit 1
fi

if [ ! -f "$STUDENT_PROGRAM" ]; then
    echo "Error: File $STUDENT_PROGRAM not found!"
    exit 1
fi

# Ensure executable permission
chmod +x "$STUDENT_PROGRAM"

# Extract roll number (before .out)
BASENAME=$(basename "$STUDENT_PROGRAM")
ROLL_NUMBER="${BASENAME%.out}"

echo "Testing submission of: $ROLL_NUMBER"

# ---------------------------------------------
# Setup output folder
# ---------------------------------------------
mkdir -p Program-outputs

RESULTS_FILE="results.txt"
echo "" > "$RESULTS_FILE"   # clear previous results

TOTAL=0
CORRECT=0
TOTAL_TIME="0.0"

# ---------------------------------------------
# Process each input file
# ---------------------------------------------
# ---------------------------------------------
# Process each input file
# ---------------------------------------------
for INPUT in Inputs/input*.txt; do

    TOTAL=$((TOTAL + 1))

    INPUT_NAME=$(basename "$INPUT")
    
    # 1. Extract the number from the input filename (e.g., input1.txt -> 1)
    #    We use tr to delete anything that isn't a digit.
    NUM=$(echo "$INPUT_NAME" | tr -dc '0-9')
    
    # 2. Define the filename exactly as the C++ code generates it
    GENERATED_FILE="output${NUM}.txt"
    
    # 3. Define the path where we want to store it
    PROGRAM_OUTPUT="Program-outputs/$GENERATED_FILE"

    # -----------------------------------------
    # Run the student's program
    # -----------------------------------------
    "./$STUDENT_PROGRAM" "$INPUT" 1> /dev/null 2> runtime_err.txt

    EXIT_CODE=$?

    # Check if run failed or if the expected output file was not created
    if [ $EXIT_CODE -ne 0 ] || [ ! -f "$GENERATED_FILE" ]; then
        echo "$INPUT_NAME   runtime-error" >> "$RESULTS_FILE"
        continue
    fi

    # -----------------------------------------
    # Move output into Program-outputs
    # -----------------------------------------
    # This is the step that was failing previously
    mv "$GENERATED_FILE" "$PROGRAM_OUTPUT"

    # -----------------------------------------
    # Compare with official output (IGNORE time)
    # -----------------------------------------
    TMP1="tmp_student.txt"
    TMP2="tmp_official.txt"
    
    # We assume the official outputs in the 'Outputs' folder 
    # are also named output1.txt, output2.txt, etc.
    OFFICIAL_OUTPUT="Outputs/$GENERATED_FILE"

    if [ ! -f "$OFFICIAL_OUTPUT" ]; then
        echo "Warning: Official output $OFFICIAL_OUTPUT missing."
        echo "$INPUT_NAME   unknown" >> "$RESULTS_FILE"
        continue
    fi

    # Remove last line (runtime) from both files before comparison
    head -n -1 "$PROGRAM_OUTPUT" > "$TMP1"
    head -n -1 "$OFFICIAL_OUTPUT" > "$TMP2"

    DIFF_RESULT=$(diff "$TMP1" "$TMP2")

    if [ "$DIFF_RESULT" = "" ]; then
        echo "$INPUT_NAME   correct" >> "$RESULTS_FILE"
        CORRECT=$((CORRECT + 1))

        # Extract kernel runtime (last line)
        LASTLINE=$(tail -n 1 "$PROGRAM_OUTPUT" | tr -d '\r' | awk '{$1=$1;print}')
        
        # Validate numeric
        if ! [[ $LASTLINE =~ ^[0-9]+([.][0-9]+)?$ ]]; then
            LASTLINE="0.0"
        fi

        # Add to total time
        TOTAL_TIME=$(awk -v a="$TOTAL_TIME" -v b="$LASTLINE" 'BEGIN{printf "%.10f", a + b}')
    else
        echo "$INPUT_NAME   wrong" >> "$RESULTS_FILE"
    fi

    rm -f "$TMP1" "$TMP2"

done

# ---------------------------------------------
# Final Summary
# ---------------------------------------------
echo "" >> "$RESULTS_FILE"
echo "Total Input Files = $TOTAL" >> "$RESULTS_FILE"
echo "Total Correct Outputs = $CORRECT" >> "$RESULTS_FILE"

if [ "$CORRECT" -gt 0 ]; then
    # compute average with awk, print 6 decimal places
    AVERAGE_TIME=$(awk -v a="$TOTAL_TIME" -v c="$CORRECT" 'BEGIN{if(c>0) printf "%.6f", a/c; else print "0.000000"}')
    echo "Average Time = $AVERAGE_TIME" >> "$RESULTS_FILE"
else
    echo "Average Time = 0" >> "$RESULTS_FILE"
fi

echo "Testing complete for $ROLL_NUMBER. See results.txt"
