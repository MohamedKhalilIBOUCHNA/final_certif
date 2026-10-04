#!/bin/bash

query() {
  psql --username=freecodecamp --dbname=number_guess \
    -X -q -t --no-align -v ON_ERROR_STOP=1 \
    --set=username="$USERNAME"
}

echo "Enter your username:"
IFS= read -r USERNAME || exit 0

USER_INFO=$(query <<'SQL'
SELECT user_id, games_played, best_game
FROM users
WHERE username = :'username';
SQL
) || exit 1

if [[ -z "$USER_INFO" ]]; then
  USER_ID=$(query <<'SQL'
INSERT INTO users(username)
VALUES (:'username')
RETURNING user_id;
SQL
  ) || exit 1

  echo "Welcome, $USERNAME! It looks like this is your first time here."
else
  IFS='|' read -r USER_ID GAMES_PLAYED BEST_GAME <<< "$USER_INFO"
  echo "Welcome back, $USERNAME! You have played $GAMES_PLAYED games, and your best game took $BEST_GAME guesses."
fi

SECRET_NUMBER=$((RANDOM % 1000 + 1))
NUMBER_OF_GUESSES=0

echo "Guess the secret number between 1 and 1000:"

while IFS= read -r GUESS; do
  NUMBER_OF_GUESSES=$((NUMBER_OF_GUESSES + 1))

  if [[ ! "$GUESS" =~ ^[+-]?[0-9]+$ ]]; then
    echo "That is not an integer, guess again:"
    continue
  fi

  # Normalize signs and leading zeros before Bash arithmetic.
  DIGITS="${GUESS#[-+]}"
  while [[ ${#DIGITS} -gt 1 && "$DIGITS" == 0* ]]; do
    DIGITS="${DIGITS#0}"
  done

  # Very large integers are outside the secret number's range.
  if [[ ${#DIGITS} -gt 4 ]]; then
    VALUE=1001
  else
    VALUE=$((10#$DIGITS))
  fi

  if [[ "$GUESS" == -* ]]; then
    VALUE=$((-VALUE))
  fi

  if (( VALUE > SECRET_NUMBER )); then
    echo "It's lower than that, guess again:"
  elif (( VALUE < SECRET_NUMBER )); then
    echo "It's higher than that, guess again:"
  else
    query >/dev/null <<SQL
UPDATE users
SET games_played = games_played + 1,
    best_game = CASE
      WHEN best_game IS NULL OR $NUMBER_OF_GUESSES < best_game
        THEN $NUMBER_OF_GUESSES
      ELSE best_game
    END
WHERE user_id = $USER_ID;
SQL
    if [[ $? -ne 0 ]]; then
      exit 1
    fi

    echo "You guessed it in $NUMBER_OF_GUESSES tries. The secret number was $SECRET_NUMBER. Nice job!"
    exit 0
  fi
done
