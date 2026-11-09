# CUTMind Data Collection Form: Ready to Paste (SHORT version, ~2 minutes)

Build this in **Google Forms** (or Microsoft Forms). Copy each block exactly. Keep the order, because the training script depends on it.

**Form settings**
- Do NOT collect email addresses. Do NOT turn on "limit to 1 response" (it forces a Google login and reduces responses).
- Make every question **Required**.
- Turn on "Show progress bar".
- Section break after every Part (A, B, C, D).
- Test on your phone first. Most students will answer on mobile.

Replace everything in [SQUARE BRACKETS].

---

## Form title
**CUTMind Student Wellbeing Study (anonymous, 2 minutes)**

## Form description
Hi! I am [YOUR NAME], a final-year student at CUT. For my research project I am building CUTMind, a mobile app that helps students check in on their wellbeing. To make it accurate for CUT students, I need real responses from real students.

This takes about 2 minutes, is anonymous, and is voluntary. Thank you for helping!

---

## PART A: Consent (Section 1)

**Title:** Information and consent

**Description text (paste in the section description):**

> **Purpose:** To train and test a machine-learning model that estimates student stress/anxiety risk from a short daily check-in. This is part of the module IPJ527C Advanced Research Project at CUT (Supervisor: [SUPERVISOR NAME]; Ethics ref: [REF NO. or "approved as part of project proposal"]).
>
> **What you will do:** Answer 5 quick rating questions and 4 short questions about how you have felt over the last 2 weeks.
>
> **Anonymity:** We do NOT collect your name, student number, or email. Your answers cannot be traced back to you. Results will only be reported as group statistics.
>
> **Voluntary:** You may stop at any time by closing the form. Nothing is saved until you press Submit. Because responses are anonymous, they cannot be withdrawn after submitting.
>
> **Data protection (POPIA):** Data is stored securely, used only for this research, and deleted after the project is assessed and any publication is complete.
>
> **Risks:** Some questions are about feelings such as stress, anxiety, and low mood. If anything upsets you, you can stop, and support contacts are listed at the end of the form.
>
> **This is NOT a diagnosis or medical test.**
>
> Questions? Contact [YOUR CUT EMAIL].

**Q1.** I have read the information above and I agree to take part voluntarily.
- Type: Multiple choice (required)
- Options: `Yes, I agree` / `No, I do not agree`
- *Go to section based on answer:* "No" -> **Submit form** (end).

**Q2.** I confirm that I am 18 years or older.
- Type: Multiple choice (required)
- Options: `Yes` / `No`
- *Go to section based on answer:* "No" -> **Submit form** (end).

---

## PART B: About you (Section 2)

**Q3.** Age group
- Dropdown: `18-20` / `21-23` / `24-26` / `27 or older`

**Q4.** Faculty
- Dropdown: `Engineering, Built Environment and Information Technology` / `Management Sciences` / `Humanities` / `Health and Environmental Sciences` / `Other`

**Q5.** Year of study
- Dropdown: `1st year` / `2nd year` / `3rd year` / `4th year or postgraduate`

---

## PART C: Your check-in today (Section 3)

**Description text:** Please answer based on how you feel **today**, from 1 to 5.

Use **Linear scale 1 to 5** for each. Set the labels exactly as shown (these match the app).

**Q6.** 😰 Stress level: How stressed have you felt today?
- 1 label: `Not stressed` | 5 label: `Extremely stressed`

**Q7.** 😟 Anxiety: How anxious or worried have you felt today?
- 1 label: `Calm` | 5 label: `Very anxious`

**Q8.** 😴 Sleep quality: How well did you sleep last night?
- 1 label: `Very poor` | 5 label: `Excellent`

**Q9.** 🎯 Motivation: How motivated do you feel for your studies?
- 1 label: `No motivation` | 5 label: `Highly motivated`

**Q10.** 🤝 Social wellbeing: How connected do you feel to others around you?
- 1 label: `Very isolated` | 5 label: `Very connected`

---

## PART D: Wellbeing screener, PHQ-4 (Section 4)

**Description text:**
> Over the **last 2 weeks**, how often have you been bothered by the following problems?

For **every** item use **Multiple choice** with these 4 options (or one **Multiple-choice grid**: rows = the 4 items, columns = the 4 options. A grid feels faster to students):
`Not at all` / `Several days` / `More than half the days` / `Nearly every day`

| Form Q | Question text |
|---|---|
| Q11 | Feeling nervous, anxious or on edge |
| Q12 | Not being able to stop or control worrying |
| Q13 | Little interest or pleasure in doing things |
| Q14 | Feeling down, depressed, or hopeless |

> Source: Kroenke, K., Spitzer, R.L., Williams, J.B.W. & Löwe, B. (2009). An ultra-brief screening scale for anxiety and depression: the PHQ-4. *Psychosomatics, 50*(6), 613-621. Free to use, no permission required (Pfizer PHQ screeners).
> Scoring (done by the script): Not at all = 0 ... Nearly every day = 3; total 0-12. Q11+Q12 = anxiety (GAD-2), Q13+Q14 = depression (PHQ-2).
> Label used by CUTMind: **0-2 = low, 3-5 = moderate, 6-12 = high** (6+ is the published threshold for moderate-to-severe distress).

---

## Confirmation message (Settings > Presentation)

> Thank you, your response has been recorded! 💙
>
> This form is not a diagnosis. If you are struggling, you are not alone and help is available:
>
> - **CUT Counselling Services:** 051 507 3017 | counselling@cut.ac.za
> - **SADAG Suicide Crisis Line (24/7):** 0800 567 567
> - **LifeLine:** 0861 322 322
> - **Emergency:** 112 (from a cellphone) or 10111
>
> If you would like to see the CUTMind app, contact [YOUR CUT EMAIL].

*(Verify every phone number before launch. Use the same numbers your app shows.)*

---

## Message to send to students (WhatsApp / eThuto / posters)

> Hi CUT students 👋 I'm [NAME], a final-year IT student building **CUTMind**, a wellbeing app for CUT students. I need real student responses to train it properly. It's a **2-minute, 100% anonymous** form (no name, no student number). Please help and share with your class group 🙏
> 👉 [FORM LINK]
> (Optional: [INCENTIVE, e.g. 5 random respondents win R50 airtime. Use a separate, unlinked form for the draw so responses stay anonymous.])

---

## Export for training

1. In Google Forms: **Responses > Link to Sheets > File > Download > CSV**.
2. Save as `responses.csv` next to `train_model.py`, then run `python train_model.py --csv responses.csv` (PHQ-4 is the default).
3. The script expects exactly 16 columns (Timestamp + Q1 to Q14). Do not add, delete, or reorder questions.

---

# APPENDIX (OPTIONAL): Long version with DASS-21

Only use this if your supervisor prefers the DASS-21 (it also measures *stress*, which PHQ-4 does not). Replace Part D above with the section below, and run the script with `--instrument dass21`. Expect fewer responses (about 6 minutes per student). Do not mix PHQ-4 and DASS-21 responses in one dataset.

## PART D: DASS-21 (Section 4, long version)

**Description text:**
> Please read each statement and select a number 0, 1, 2 or 3 that indicates how much the statement applied to you **over the past week**. There are no right or wrong answers. Do not spend too much time on any statement.
>
> **0** = Did not apply to me at all
> **1** = Applied to me to some degree, or some of the time
> **2** = Applied to me to a considerable degree, or a good part of the time
> **3** = Applied to me very much, or most of the time

For **every** item below use **Linear scale 0 to 3** (set 0 label `Did not apply`, 3 label `Applied very much`). Keep the numbering "" in the question text so you can keep track.

| Form Q | Question text |
|---|---|
| Q11 | I found it hard to wind down |
| Q12 | I was aware of dryness of my mouth |
| Q13 | I couldn't seem to experience any positive feeling at all |
| Q14 | I experienced breathing difficulty (e.g. excessively rapid breathing, breathlessness in the absence of physical exertion) |
| Q15 | I found it difficult to work up the initiative to do things |
| Q16 | I tended to over-react to situations |
| Q17 | I experienced trembling (e.g. in the hands) |
| Q18 | I felt that I was using a lot of nervous energy |
| Q19 | I was worried about situations in which I might panic and make a fool of myself |
| Q20 | I felt that I had nothing to look forward to |
| Q21 | I found myself getting agitated |
| Q22 | I found it difficult to relax |
| Q23 | I felt down-hearted and blue |
| Q24 | I was intolerant of anything that kept me from getting on with what I was doing |
| Q25 | I felt I was close to panic |
| Q26 | I was unable to become enthusiastic about anything |
| Q27 | I felt I wasn't worth much as a person |
| Q28 | I felt that I was rather touchy |
| Q29 | I was aware of the action of my heart in the absence of physical exertion (e.g. sense of heart rate increase, heart missing a beat) |
| Q30 | I felt scared without any good reason |
| Q31 | I felt that life was meaningless |

> Source: Lovibond, S.H. & Lovibond, P.F. (1995). *Manual for the Depression Anxiety Stress Scales* (2nd ed.). Sydney: Psychology Foundation. The DASS is free to use for research; check the UNSW DASS page for the current permission statement and cite it in your report.

---

