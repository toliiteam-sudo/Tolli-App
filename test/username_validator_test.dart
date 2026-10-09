import 'package:flutter_test/flutter_test.dart';
import 'package:tolii/utils/username_validator.dart';

void main() {
  group('UsernameValidator Tests', () {
    test('Valid Instagram-style usernames', () {
      expect(UsernameValidator.isValidFormat('vatsal'), isTrue);
      expect(UsernameValidator.isValidFormat('vatsal07'), isTrue);
      expect(UsernameValidator.isValidFormat('vatsal_parmar'), isTrue);
      expect(UsernameValidator.isValidFormat('vatsal.parmar'), isTrue);
      expect(UsernameValidator.isValidFormat('vatsal_07'), isTrue);
      expect(UsernameValidator.isValidFormat('vatsal.p'), isTrue);
    });

    test('Invalid format usernames', () {
      expect(UsernameValidator.isValidFormat('va'), isFalse);
      expect(UsernameValidator.isValidFormat('123vatsal'), isFalse);
      expect(UsernameValidator.isValidFormat('_vatsal'), isFalse);
      expect(UsernameValidator.isValidFormat('.vatsal'), isFalse);
      expect(UsernameValidator.isValidFormat('vatsal_'), isFalse);
      expect(UsernameValidator.isValidFormat('vatsal.'), isFalse);
      expect(UsernameValidator.isValidFormat('vatsal..parmar'), isFalse);
      expect(UsernameValidator.isValidFormat('vatsal-parmar'), isFalse);
      expect(UsernameValidator.isValidFormat('vatsal parmar'), isFalse);
      expect(UsernameValidator.isValidFormat('@vatsal'), isFalse);
      expect(UsernameValidator.isValidFormat('vatsal!23'), isFalse);
    });

    test('Reserved usernames normalization & check', () {
      expect(UsernameValidator.normalize('Admin'), 'admin');
      expect(UsernameValidator.isReserved('Admin'), isTrue);
      expect(UsernameValidator.isValidFormat('Admin'), isFalse);

      expect(UsernameValidator.normalize('TOLII'), 'tolii');
      expect(UsernameValidator.isReserved('TOLII'), isTrue);
      expect(UsernameValidator.isValidFormat('TOLII'), isFalse);
    });

    test('Automatic base username generation from name', () {
      expect(UsernameValidator.generateBaseUsername('Vatsal', 'Parmar'), 'vatsalparmar');
      expect(UsernameValidator.generateBaseUsername('Vatsal Kumar', 'Parmar'), 'vatsalkumarparmar');
      expect(UsernameValidator.generateBaseUsername('Rahul', 'Shah'), 'rahulshah');
      expect(UsernameValidator.generateBaseUsername('John', 'Doe'), 'johndoe');
      expect(UsernameValidator.generateBaseUsername('Vatsal', ''), 'vatsal');
      expect(UsernameValidator.generateBaseUsername('Vatsal-Parmar', ''), 'vatsalparmar');
      expect(UsernameValidator.generateBaseUsername('Vātsal', 'Parmār'), 'vatsalparmar');
      expect(UsernameValidator.generateBaseUsername('Vatsal @', 'Parmar'), 'vatsalparmar');
    });
  });
}
