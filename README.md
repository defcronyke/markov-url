# Markov URL

## Get markov text from a URL

### Currently supported URLs are similar to:

```shell
printf "aHR0cHM6Ly93d3cuY2JjLmNhL25ld3MvdGVjaG5vbG9neS9hcmNoZW9sb2dpc3RzLWNlcmVtb25pYWwtY2hhcmlvdC1wb21wZWlpLTEuNTkzMTcxMg==" | base64 -d
```

### Usage:

```shell
# The optional arguments can be passed in whichever order you prefer.
bash <(curl -sL https://tinyurl.com/markov-url) [url] [approx-num-words]
```
