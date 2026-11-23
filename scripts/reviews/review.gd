class_name Review
extends RefCounted
## One customer's review of an order: 1-5 stars plus what they complained about and
## what they liked (display text, tallied for the day report).

var stars: int = 5
var complaints: Array[String] = []
var compliments: Array[String] = []
