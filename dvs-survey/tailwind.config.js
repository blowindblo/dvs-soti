// /** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./src/**/*.{html,js}"],
  theme: {
    extend: {},
  },
  plugins: [require('@tailwindcss/typography'), require("daisyui")],
  daisyui: {
    styled: true,
    themes: ["cupcake"],
    base: true,
    utils: true,
    logs: true,
    rtl: false,
  },
};
