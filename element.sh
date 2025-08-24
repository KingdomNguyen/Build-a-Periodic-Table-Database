# Periodic Table Script
#!/bin/bash
PSQL="psql -X --username=freecodecamp --dbname=periodic_table --tuples-only -c"

MAIN_PROGRAM() {
  if [[ -z $1 ]]
  then
    echo "Please provide an element as an argument."
  else
    PRINT_ELEMENT $1
  fi
}

PRINT_ELEMENT() {
  INPUT=$1
  if [[ ! $INPUT =~ ^[0-9]+$ ]]
  then
    ATOMIC_NUMBER=$(echo $($PSQL "SELECT atomic_number FROM elements WHERE symbol='$INPUT' OR name='$INPUT';") | sed 's/ //g')
  else
    ATOMIC_NUMBER=$(echo $($PSQL "SELECT atomic_number FROM elements WHERE atomic_number=$INPUT;") | sed 's/ //g')
  fi
  
  if [[ -z $ATOMIC_NUMBER ]]
  then
    echo "I could not find that element in the database."
  else
    TYPE_ID=$(echo $($PSQL "SELECT type_id FROM properties WHERE atomic_number=$ATOMIC_NUMBER;") | sed 's/ //g')
    NAME=$(echo $($PSQL "SELECT name FROM elements WHERE atomic_number=$ATOMIC_NUMBER;") | sed 's/ //g')
    SYMBOL=$(echo $($PSQL "SELECT symbol FROM elements WHERE atomic_number=$ATOMIC_NUMBER;") | sed 's/ //g')
    ATOMIC_MASS=$(echo $($PSQL "SELECT atomic_mass FROM properties WHERE atomic_number=$ATOMIC_NUMBER;") | sed 's/ //g')
    MELTING_POINT_CELSIUS=$(echo $($PSQL "SELECT melting_point_celsius FROM properties WHERE atomic_number=$ATOMIC_NUMBER;") | sed 's/ //g')
    BOILING_POINT_CELSIUS=$(echo $($PSQL "SELECT boiling_point_celsius FROM properties WHERE atomic_number=$ATOMIC_NUMBER;") | sed 's/ //g')
    TYPE=$(echo $($PSQL "SELECT type FROM types WHERE type_id=$TYPE_ID;") | sed 's/ //g')

    echo "The element with atomic number $ATOMIC_NUMBER is $NAME ($SYMBOL). It's a $TYPE, with a mass of $ATOMIC_MASS amu. $NAME has a melting point of $MELTING_POINT_CELSIUS celsius and a boiling point of $BOILING_POINT_CELSIUS celsius."
  fi
}

FIX_DB() {
  # Rename columns
  $PSQL "ALTER TABLE properties RENAME COLUMN weight TO atomic_mass;" > /dev/null
  $PSQL "ALTER TABLE properties RENAME COLUMN melting_point TO melting_point_celsius;" > /dev/null
  $PSQL "ALTER TABLE properties RENAME COLUMN boiling_point TO boiling_point_celsius;" > /dev/null

  # Add NOT NULL constraints
  $PSQL "ALTER TABLE properties ALTER COLUMN melting_point_celsius SET NOT NULL;" > /dev/null
  $PSQL "ALTER TABLE properties ALTER COLUMN boiling_point_celsius SET NOT NULL;" > /dev/null
  $PSQL "ALTER TABLE elements ALTER COLUMN symbol SET NOT NULL;" > /dev/null
  $PSQL "ALTER TABLE elements ALTER COLUMN name SET NOT NULL;" > /dev/null

  # Add UNIQUE constraints
  $PSQL "ALTER TABLE elements ADD UNIQUE(symbol);" > /dev/null
  $PSQL "ALTER TABLE elements ADD UNIQUE(name);" > /dev/null

  # Add foreign key
  $PSQL "ALTER TABLE properties ADD FOREIGN KEY (atomic_number) REFERENCES elements(atomic_number);" > /dev/null

  # Create types table
  $PSQL "CREATE TABLE types(type_id SERIAL PRIMARY KEY, type VARCHAR(20) NOT NULL);" > /dev/null
  $PSQL "INSERT INTO types(type) SELECT DISTINCT type FROM properties;" > /dev/null

  # Add type_id column and update values
  $PSQL "ALTER TABLE properties ADD COLUMN type_id INT;" > /dev/null
  $PSQL "UPDATE properties SET type_id = types.type_id FROM types WHERE properties.type = types.type;" > /dev/null
  $PSQL "ALTER TABLE properties ALTER COLUMN type_id SET NOT NULL;" > /dev/null
  $PSQL "ALTER TABLE properties ADD FOREIGN KEY(type_id) REFERENCES types(type_id);" > /dev/null

  # Capitalize symbols
  $PSQL "UPDATE elements SET symbol = INITCAP(symbol);" > /dev/null

  # Fix atomic mass decimals
  $PSQL "ALTER TABLE properties ALTER COLUMN atomic_mass TYPE DECIMAL;" > /dev/null
  $PSQL "UPDATE properties SET atomic_mass = TRIM(TRAILING '0' FROM atomic_mass::TEXT)::DECIMAL;" > /dev/null

  # Add missing elements
  $PSQL "INSERT INTO elements(atomic_number, symbol, name) VALUES(9, 'F', 'Fluorine');" > /dev/null
  $PSQL "INSERT INTO properties(atomic_number, atomic_mass, melting_point_celsius, boiling_point_celsius, type_id) VALUES(9, 18.998, -220, -188.1, (SELECT type_id FROM types WHERE type='nonmetal'));" > /dev/null
  
  $PSQL "INSERT INTO elements(atomic_number, symbol, name) VALUES(10, 'Ne', 'Neon');" > /dev/null
  $PSQL "INSERT INTO properties(atomic_number, atomic_mass, melting_point_celsius, boiling_point_celsius, type_id) VALUES(10, 20.18, -248.6, -246.1, (SELECT type_id FROM types WHERE type='nonmetal'));" > /dev/null

  # Remove element 1000 and type column
  $PSQL "DELETE FROM properties WHERE atomic_number=1000;" > /dev/null
  $PSQL "DELETE FROM elements WHERE atomic_number=1000;" > /dev/null
  $PSQL "ALTER TABLE properties DROP COLUMN type;" > /dev/null
}

START_PROGRAM() {
  # Check if database needs fixing
  CHECK=$($PSQL "SELECT COUNT(*) FROM information_schema.columns WHERE table_name='properties' AND column_name='weight';")
  if [[ $CHECK -gt 0 ]]
  then
    FIX_DB
  fi
  MAIN_PROGRAM $1
}

START_PROGRAM $1
# Database fix script
# End of file
