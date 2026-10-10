// a script of its own file: the list filled
var dishes = ["soup", "bread", "cheese"];
var list = document.getElementById("list");
for (var i = 0; i < dishes.length; i++) {
  var li = document.createElement("li");
  li.textContent = (i + 1) + ". " + dishes[i];
  list.appendChild(li);
}
console.log("the list has " + list.children.length + " dishes");
