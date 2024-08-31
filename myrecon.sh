#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' 

# Banner
text_MMHR=$(figlet -f slant MMHR)
echo -e "${BLUE}${text_MMHR}${NC}"
echo -e "${GREEN}└──────$ created by Mahmoud Elsady${NC}"

# Help Menu
show_help() {
    echo -e "     ${BLUE}Usage: $0 [options] <domain>${NC}"
    echo -e "     	${GREEN}Options:${NC}"
    echo -e "     		${YELLOW}-h,   --help         Display this help message${NC}"
    echo -e "     		${YELLOW}-sub, --subdomain    Run all tools for the given domain${NC}"
    echo -e "     		${YELLOW}-dirb, --dirb       Run dirb on the specified file${NC}"
    echo -e "     ${GREEN}Example: $0 --subdomain example.com${NC}"
    echo -e "     ${GREEN}Example: $0 --dirb ./myrecon.sh${NC}"
}

# Initialize variables
DOMAIN=""
RUN_TOOLS=0
RUN_DIRB=0
DIRB_FILE=""

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        --subdomain|-sub)
            RUN_TOOLS=1
            DOMAIN="$2"
            shift
            ;;
        --dirb|-dirb)
            RUN_DIRB=1
            DIRB_FILE="$2"
            shift
            ;;
        *)
            if [ -z "$DOMAIN" ] && [ $RUN_TOOLS -eq 1 ]; then
                DOMAIN="$1"
            elif [ -z "$DIRB_FILE" ] && [ $RUN_DIRB -eq 1 ]; then
                DIRB_FILE="$1"
            else
                echo -e "${RED}[xxx]Error: Invalid option or argument: $1${NC}"
                show_help
                exit 1
            fi
            ;;
    esac
    shift
done

# Check if domain is provided and valid
if [ $RUN_TOOLS -eq 0 ] && [ $RUN_DIRB -eq 0 ]; then
    echo -e "${RED}[x]Error: No valid option specified.${NC}"
    show_help
    exit 1
fi

if [ $RUN_TOOLS -eq 1 ] && [ -z "$DOMAIN" ]; then
    echo -e "${RED}[x]Error: No valid domain specified.${NC}"
    show_help
    exit 1
fi

# Check if dirb is installed if needed
if [ $RUN_DIRB -eq 1 ] && ! command -v dirb &> /dev/null; then
    echo -e "${RED}[xxx]Error: dirb is not installed.${NC}"
    exit 1
fi

# Variables
OUTPUT_DIR="output_$DOMAIN"
MERGED_FILE="$OUTPUT_DIR/merged.txt"
HTTPX_OUTPUT="$OUTPUT_DIR/httpx_results.txt"
HTTPROBE_OUTPUT="$OUTPUT_DIR/httprobe_results.txt"
FINAL_MERGED_FILE="$OUTPUT_DIR/final_results.txt"
DIRB_OUTPUT="$OUTPUT_DIR/dirb_results.txt"

# Create output directory based on domain name
mkdir -p $OUTPUT_DIR

# Run tools and save outputs
if [ $RUN_TOOLS -eq 1 ]; then
    echo -e "${BLUE}[+]Running Subfinder...${NC}"
    subfinder -d $DOMAIN -o $OUTPUT_DIR/subfinder.txt

    echo -e "${BLUE}[+]Running Assetfinder...${NC}"
    assetfinder $DOMAIN > $OUTPUT_DIR/assetfinder.txt

    echo -e "${BLUE}[+]Running Sublist3r...${NC}"
    sublist3r -d $DOMAIN -o $OUTPUT_DIR/sublist3r.txt

    # Merge files and remove duplicates
    echo -e "${YELLOW}[+]Merging files and removing duplicates...${NC}"
    cat $OUTPUT_DIR/subfinder.txt \
        $OUTPUT_DIR/assetfinder.txt \
        $OUTPUT_DIR/sublist3r.txt | sort -u > $MERGED_FILE

    # Run httpx and httprobe
    echo -e "${BLUE}[+]Running httpx...${NC}"
    httpx -l $MERGED_FILE -o $HTTPX_OUTPUT

    echo -e "${BLUE}[+]Running httprobe...${NC}"
    cat $MERGED_FILE | httprobe > $HTTPROBE_OUTPUT

    # Merge httpx and httprobe results, and remove duplicates
    echo -e "${YELLOW}[+]Merging httpx and httprobe results and removing duplicates...${NC}"
    cat $HTTPX_OUTPUT $HTTPROBE_OUTPUT | sort -u > $FINAL_MERGED_FILE

    echo -e "${GREEN}All tools have finished running. Results are saved in the $OUTPUT_DIR directory.${NC}"
    echo -e "${GREEN}Final merged file with unique entries: $FINAL_MERGED_FILE ${NC}"
fi

# Additional tools - dirb
if [ $RUN_DIRB -eq 1 ]; then
    if [ -f "$DIRB_FILE" ]; then
        echo -e "${BLUE}[+]Running dirb on final results...${NC}"
        while IFS= read -r subdomain; do
            echo -e "${BLUE}[+]Running dirb on http://$subdomain...${NC}"
            dirb http://$subdomain -o "$OUTPUT_DIR/dirb_results_$subdomain.txt"
        done < "$DIRB_FILE"
        echo -e "${GREEN}Dirb has finished running. Results are saved in the $OUTPUT_DIR directory.${NC}"
    else
        echo -e "${RED}[xxx]Error: Specified file does not exist.${NC}"
    fi
fi
