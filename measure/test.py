import requests

url = "https://circumfit.onrender.com/calculate-bri"
files = {
    'image_side': open(r'C:\Users\elias\Downloads\photo_side_germine.jpg', 'rb'),
    'image_front': open(r'C:\Users\elias\Downloads\photo_front_germine.jpg', 'rb')
}
data = {
    'user_height_cm': '163',
    'patient_id': 'test-patient',
    'sex': 'Female',
    'age': '30',
    'weight_kg': '60'
}

response = requests.post(url, files=files, data=data)

print("Status Code:", response.status_code)
print("Response:", response.json())
