FROM semenovp/tiny-elm:latest 
COPY frontend/ elm-build/

RUN cd /elm-build \
    && elm make src/Main.elm --optimize --output=assets/elm.js

FROM ghcr.io/gleam-lang/gleam:v1.4.1-erlang-alpine

# Add project code
COPY backend/ /build/

# Compile the project
RUN cd /build \
  && gleam export erlang-shipment \
  && mv build/erlang-shipment /app \
  && rm -r /build

# Run the server
WORKDIR /app
RUN mkdir -p /frontend/assets/
COPY --from=0 /elm-build/assets/elm.js ../frontend/assets/elm.js
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["run"]
