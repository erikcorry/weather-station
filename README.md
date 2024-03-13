# Toit Weather Station

This branch is the code for part 1 of the weather station blog post.

See https://blog.toit.io/ for the blog post it corresponds to.

To use this, edit `app/app.toit` to use your own API key from
openweathermap.org.  You also need to download the packages
with:

```
cd app
jag pkg install
```

or

```
cd app
toit.pkg install
```

Run the text-only program on your laptop with:

```
jag run -d host app.toit
```

or

```
toit.run app.toit
```
