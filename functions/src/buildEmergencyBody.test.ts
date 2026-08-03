import {buildEmergencyBody} from "./index";

describe("buildEmergencyBody", () => {
  it("includes a Google Maps link when both coordinates are present", () => {
    expect(buildEmergencyBody(-23.55, -46.63)).toBe(
      "Uma pessoa da sua família apertou o botão de emergência." +
        " https://maps.google.com/?q=-23.55,-46.63"
    );
  });

  it("omits the map link when only latitude is present", () => {
    expect(buildEmergencyBody(-23.55, undefined)).toBe(
      "Uma pessoa da sua família apertou o botão de emergência."
    );
  });

  it("omits the map link when only longitude is present", () => {
    expect(buildEmergencyBody(undefined, -46.63)).toBe(
      "Uma pessoa da sua família apertou o botão de emergência."
    );
  });

  it("omits the map link when neither coordinate is present", () => {
    expect(buildEmergencyBody(undefined, undefined)).toBe(
      "Uma pessoa da sua família apertou o botão de emergência."
    );
  });
});
