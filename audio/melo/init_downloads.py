

if __name__ == '__main__':

    from melo.api import TTS
    device = 'cpu'
    # Chi download model ZH (tieng Trung) - tiet kiem ~500MB
    models = {
        'ZH': TTS(language='ZH', device=device),
    }
    print("Model ZH da download xong.")