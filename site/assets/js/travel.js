// Destination cards: clicking a card shows its matching detail section
// (data-target -> section id) and hides the others. Clicking the active
// card again hides it.

const travelCards = document.querySelectorAll(".travel-card");
const travelDetails = document.querySelectorAll(".travel-detail");

travelCards.forEach((card) => {

	card.addEventListener("click", () => {

		const targetId = card.dataset.target;
		const selectedDetail = document.getElementById(targetId);
		const wasOpen = selectedDetail && !selectedDetail.hidden;

		travelDetails.forEach((detail) => {
			detail.hidden = true;
		});

		travelCards.forEach((other) => {
			other.classList.remove("is-active");
			other.setAttribute("aria-expanded", "false");
		});

		if (selectedDetail && !wasOpen) {
			selectedDetail.hidden = false;
			card.classList.add("is-active");
			card.setAttribute("aria-expanded", "true");
			selectedDetail.scrollIntoView({ behavior: "smooth", block: "nearest" });
		}

	});

});

// Photo viewer: clicking a gallery photo shows it full-size. Click anywhere
// or press Esc to close.

const lightbox = document.createElement("div");
lightbox.className = "lightbox";
lightbox.hidden = true;
lightbox.innerHTML = '<img alt="" /><p></p>';
document.body.appendChild(lightbox);

const lightboxImg = lightbox.querySelector("img");
const lightboxCaption = lightbox.querySelector("p");

function closeLightbox() {
	lightbox.hidden = true;
	lightboxImg.src = "";
}

document.querySelectorAll(".gallery-item").forEach((item) => {

	item.addEventListener("click", () => {
		const img = item.querySelector("img");
		lightboxImg.src = img.src;
		lightboxImg.alt = img.alt;
		lightboxCaption.textContent = img.alt;
		lightbox.hidden = false;
	});

});

// The template (main.js) closes the open article on any body click and on
// Esc, so stop those events here or closing a photo would close the article too.
lightbox.addEventListener("click", (event) => {
	event.stopPropagation();
	closeLightbox();
});

window.addEventListener("keyup", (event) => {
	if (event.key === "Escape" && !lightbox.hidden) {
		event.stopPropagation();
		closeLightbox();
	}
}, true);
