FROM node:22
COPY frontend/ elm-build/

RUN npm install -g elm
RUN npm install -g uglify-js
RUN cd /elm-build \
    && elm make src/Main.elm --optimize --output=assets/elm.js \
    && (uglifyjs assets/elm.js --compress 'pure_funcs=[F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9],pure_getters,keep_fargs=false,unsafe_comps,unsafe' | uglifyjs --mangle --output assets/elm.min.js)

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
COPY --from=0 /elm-build/assets/elm.min.js ../frontend/assets/elm.js
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["run"]
